import Foundation
import SQLite3
import CryptoKit

func hashSHA256(input: String) -> String {
    let inputData = Data(input.utf8)
    let hashed = SHA256.hash(data: inputData)
    
    return hashed.compactMap { String(format: "%02x", $0) }.joined()
}

struct Block {
    var service: String
    var user_id: String
    var nonce: String
    var timestamp: String
    var block_hash: String
}

class DataBaseManager {
    var db: OpaquePointer?
    
    let dbPath = FileManager.default.urls(for: .documentDirectory,in: .userDomainMask).first!.appendingPathComponent("ledger.sqlite").path

    
    init() {
        // Open the database connection
        if sqlite3_open(dbPath, &db) != SQLITE_OK {
            print("Error opening database")
        }
        self.createTableIfNotExists()
    }
    
    deinit {
        // Close the database connection when the object is deallocated
        sqlite3_close(db)
    }
    
    private func createTableIfNotExists() {
        
        /// Creates the 'ledger' table in the database if it does not already exist.
        ///
        /// - Note: This function constructs a CREATE TABLE query to create the 'ledger' table with columns for 'service',
        ///         'user_id', 'nonce', 'timestamp', and 'block_hash'. The query is executed, and if the table is
        ///         successfully created or already exists, a success message is printed. Otherwise, an error message is
        ///         printed.
        
        let createTableQuery = """
        CREATE TABLE IF NOT EXISTS ledger (
            service TEXT,
            user_id TEXT,
            nonce TEXT,
            timestamp TEXT,
            block_hash TEXT
        );
        """
        
        
        var createTableStatement: OpaquePointer?
        if sqlite3_prepare_v2(db, createTableQuery, -1, &createTableStatement, nil) == SQLITE_OK {
            if sqlite3_step(createTableStatement) == SQLITE_DONE {
                print("Table 'ledger' created or already exists.")
            } else {
                print("Error creating table: \(String(cString: sqlite3_errmsg(db)))")
            }
            
            sqlite3_finalize(createTableStatement)
        } else {
            print("Error preparing create table statement: \(String(cString: sqlite3_errmsg(db)))")
        }
    }
    
    
    private func writeBlock(service: String, user_id: String, nonce: String, timestamp: String, block_hash: String) {

        /// Inserts a new block record into the ledger table.
        ///
        /// - Parameters:
        ///   - service: The service associated with the block.
        ///   - user_id: The user ID associated with the block.
        ///   - nonce: The nonce value of the block.
        ///   - timestamp: The timestamp of the block.
        ///   - block_hash: The hash value of the block.
        ///
        /// - Note: This function prepares an INSERT query to add a new block record into the `ledger` table.
        ///         The provided data is bound to the query parameters, and the query is executed to insert the block.
        ///         The function also handles error cases and prints appropriate messages.
        
        let insertQuery = """
        INSERT INTO ledger (service, user_id, nonce, timestamp, block_hash)
        VALUES (?, ?, ?, ?, ?)
        """
        
        var insertStatement: OpaquePointer?
        if sqlite3_prepare_v2(db, insertQuery, -1, &insertStatement, nil) == SQLITE_OK {
            sqlite3_bind_text(insertStatement, 1, (service as NSString).utf8String, -1, nil)
            sqlite3_bind_text(insertStatement, 2, (user_id as NSString).utf8String, -1, nil)
            sqlite3_bind_text(insertStatement, 3, (nonce as NSString).utf8String, -1, nil)
            sqlite3_bind_text(insertStatement, 4, (timestamp as NSString).utf8String, -1, nil)
            sqlite3_bind_text(insertStatement, 5, (block_hash as NSString).utf8String, -1, nil)
            
            if sqlite3_step(insertStatement) != SQLITE_DONE {
                print("Error inserting data into ledger table")
            } else {
                print("Block written to ledger successfully")
            }
            
            sqlite3_finalize(insertStatement) // Properly finalize the statement
        } else {
            print("Error preparing insert statement:", String(cString: sqlite3_errmsg(db)))
        }
    }
    
    
    func getLastBlock(service: String, user_id: String) -> Block? {
        
        /// Retrieves the most recent block from the ledger for a specific service and user.
        ///
        /// - Parameters:
        ///   - service: The service associated with the block.
        ///   - user_id: The user ID associated with the block.
        ///
        /// - Returns: A `Block` object representing the most recent block for the specified service and user, or `nil` if no matching block is found.
        ///
        var statement: OpaquePointer?
        var block: Block?
        
        let query = """
        SELECT service, user_id, nonce, timestamp, block_hash
        FROM ledger
        WHERE service = ? AND user_id = ?
        ORDER BY timestamp DESC
        LIMIT 1
        """
        
        if sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK {
            let serviceCString = service.cString(using: .utf8)
            let user_idCString = user_id.cString(using: .utf8)
            
            sqlite3_bind_text(statement, 1, serviceCString, -1, nil)
            sqlite3_bind_text(statement, 2, user_idCString, -1, nil)
            
            if sqlite3_step(statement) == SQLITE_ROW {
                let service = String(cString: sqlite3_column_text(statement, 0))
                let user_id = String(cString: sqlite3_column_text(statement, 1))
                let nonce = String(cString: sqlite3_column_text(statement, 2))
                let timestamp = String(cString: sqlite3_column_text(statement, 3))
                let block_hash = String(cString: sqlite3_column_text(statement, 4))
                
                block = Block(service: service, user_id: user_id, nonce: nonce, timestamp: timestamp, block_hash: block_hash)
                
            } else if sqlite3_step(statement) == SQLITE_DONE {
                // Handle the case where no matching block is found
                print("No matching block found in the ledger.")
            }
            else {
                print("Error extracting data:", String(cString: sqlite3_errmsg(db)))
            }
        }
        
        sqlite3_finalize(statement)
        return block
    }
    
    
    func initBlock(service: String, user_id: String, nonce: String, timestamp: String, block_hash: String) {
        
        let concatString = "\(service):\(user_id):\(nonce):\(timestamp):\(block_hash)"
        let blockHash = hashSHA256(input: concatString)
        self.writeBlock(service: service, user_id: user_id, nonce: nonce, timestamp: timestamp, block_hash: blockHash)
    }
    

    func writeNextBlock(service: String, user_id: String, nonce: String, timestamp: String) {
        guard let block = getLastBlock(service: service, user_id: user_id) else {
            print("No matching block found")
            return
        }
        
        let concatString = "\(block.service):\(block.user_id):\(block.nonce):\(block.timestamp):\(block.block_hash)"
        let blockHash = hashSHA256(input: concatString)
        
        self.writeBlock(service: service, user_id: user_id, nonce: nonce, timestamp: timestamp, block_hash: blockHash)
        
    }

    
    
}


