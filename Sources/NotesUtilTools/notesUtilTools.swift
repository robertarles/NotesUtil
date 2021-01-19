import Foundation

public class NotesUtilTools {
    
    // TODO: add a logger and log levels rather than print statements
    // TODO: MUST make the backup copy of the todo file FIRST, then update the todo file!!!!!
    
    var inHeaderSection = false
    var inTodoSection = false
    let sectionsAllStartWith = "## "
    let frontMatterStartsWith = "+++"
    let todoSectionHeader = "## TODO"
    let todoItemsStartsWtih = "- [" // e.g. "- [ ] stuff" or "- [x] stuff to do"
    let completedItemsStartWith = "- [x]"
    let incompleteItemsStartWith = "- [ ]"
    let toBeJournaledIndicator = " . "
    let backupRelativeFilePath = ".bak" // directory for "logrotated" backups of todo, journal and archive
    
    public init(){

    }
    
    /**
     Takes a path to a TODO markdown file, archives completed todo's and journals "touched" todo's
     The file is expected to have a header in Hugo +++ delimited frontmatter format.
     - parameter pathToNote a string representing the path to a todo file in markdown format
     - returns an array of Strings representing the updated todo file
     */
    public func processTodoFile(pathToNote: String) throws {
        
        // get a time stamp for journaling and archiving
        let now = Date()
        let formatter = DateFormatter()
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "yyyy-MM-dd"
        let date = formatter.string(from: now)
        formatter.dateFormat = "yyyy-MM-dd HH:mma"
        let timestamp = formatter.string(from: now)
        
        // processed lines to be added to files
        var processedTodoFileLines: [String] = []
        var journalTheseLines: [String] = []
        var archiveTheseLines: [String] = []
        
        var todoFileLines: [String] = []
        do {
            todoFileLines = try readLinesFrom(pathToNote: pathToNote)
        } catch {
            throw error
        }
        
        // step through the todo lines
        for line in todoFileLines {
            
            // check if we are entering, and therefore leaving, a section
            if line.starts(with: sectionsAllStartWith) || line.starts(with: frontMatterStartsWith) {
                // headers / hugo frontmatters section detection
                // NOTE: ignoring the fact that hugo frontmatters also ENDs with +++.  The next section WILL start with `sectionsAllStartWith`
                if line.starts(with: "+++") {
                    inHeaderSection = true
                } else {
                    inHeaderSection = false
                }
                if line.starts(with: todoSectionHeader) { // allow for additional data e.g. "# TODO (work)"
                    inTodoSection = true
                } else {
                    inTodoSection = false
                }
            }
            
            // process any todo section lines
            if inTodoSection {
                // process todo lines
                if line.starts(with: todoItemsStartsWtih) {
                    let todoLineAnalysis = analyzeTodoLineItem(line: line)
                    // if its marked for archive, it MOVES to the archive, else we keep it (without the journal/touched indicator
                    if todoLineAnalysis.isMarkedForArchival == true {
                        // drop a timestamp in place of the completed checkbox
                        archiveTheseLines.append(line.replacingOccurrences(of: "[x]", with: "[\(timestamp)]"))
                    }else{
                        // place the line back in the todo file, making sure to remove the "touched" indicator if it has one
                        processedTodoFileLines.append(line.replacingOccurrences(of: "] . ", with: "] "))
                    }
                    // if it's marked for jouraling, it is copied to the journal
                    if todoLineAnalysis.isMarkedForJournaling == true {
                        // drop a timestamp in place of the "journal this" indicator
                        journalTheseLines.append(line.replacingOccurrences(of: " . ", with: " [\(timestamp)] "))
                    }
                } else {
                    // just add all other todo section lines without processing
                    processedTodoFileLines.append(line)
                }
            } else if inHeaderSection {
                if line.replacingOccurrences(of: " " , with: "").starts(with: "Date=") {
                    processedTodoFileLines.append("Date = \"\(date)\"")
                } else {
                    processedTodoFileLines.append(line)
                }
            } else {
                // all other lines are kept, unchanged
                processedTodoFileLines.append(line)
            }
            
        }
        
        // if there are no changes to make, just exit
        if archiveTheseLines.count < 1 && journalTheseLines.count < 1 {
            return
        }
        
        
        // get the file name and path, create a archive and journal file names
        let todoFilename = URL(fileURLWithPath: pathToNote).lastPathComponent
        let path = URL(fileURLWithPath: pathToNote).deletingLastPathComponent().path
        let journalFilename = todoFilename.replacingOccurrences(of: ".md", with: "-journal.md")
        let archiveFilename = todoFilename.replacingOccurrences(of: ".md", with: "-archive.md")
        
        // TODO: refactor this and arcive to a single function called once each for [journal, 
        if journalTheseLines.count > 0 {
            // add the new lines and write the updated journal
            do {
                let journalPathToFile = "\(path)/\(journalFilename)"
                let updatedJournalLines = prependArchive(lines: try readLinesFrom(pathToNote: journalPathToFile), withNewLines: journalTheseLines)
                if let updatedLines = updatedJournalLines {
                    try writeUpdatedFileAndArchive(atPath: journalPathToFile, updatedContents: updatedLines)
                }
            } catch {
                print("[ERROR] failed to write journal")
                print(error)
                return
            }
        } else {
            print("[INFO] nothing journaled")
        }
        
        if archiveTheseLines.count > 0 {
            // add the new lines and write the updated archive
            do{
                let archivePathToFile = "\(path)/\(archiveFilename)"
                let updatedArchiveLines = prependArchive(lines: try readLinesFrom(pathToNote: archivePathToFile), withNewLines: archiveTheseLines)
                if let updatedLines = updatedArchiveLines {
                    try writeUpdatedFileAndArchive(atPath: archivePathToFile, updatedContents: updatedLines)
                }
            } catch {
                print("[ERROR] failed to write archive")
                print(error)
                return
            }
        }else {
            print("[INFO] nothing archived")
        }
        
        if archiveTheseLines.count > 0 || journalTheseLines.count > 0 {
            // write the updated todo only after all journaling and archival is successful to avoid data loss, e.g. journaling/archiva fails, but todo has items moved/modified anyway
            do {
                try writeUpdatedFileAndArchive(atPath: pathToNote, updatedContents: processedTodoFileLines)
            } catch {
                print("[ERROR] failed to write todo file")
                print(error)
                return
            }
        } else {
            print("[INFO] no changes to todo file")
        }
    }
    
    /**
     Struct that represents the results of an analysis of a todo line
     */
    public struct TodoLineAnalysis {
        var isMarkedForArchival: Bool // e.g. "- [x] this is completed todo"
        var isMarkedForJournaling: Bool // e.g. "- [ ] . this is a todo touched today"
    }
    
    /**
     Takes a todo task line and returns an analysis
     - parameter line a string representing a todo task
     - returns: a TodoLineAnalysis struct response
     */
    public func analyzeTodoLineItem(line: String) -> TodoLineAnalysis {
        
        var todoLineStatus = TodoLineAnalysis(isMarkedForArchival: false, isMarkedForJournaling: false)
        // completed?
        if line.starts(with: completedItemsStartWith) {
            todoLineStatus.isMarkedForArchival = true
        }
        // marked for journaling?
        if line.starts(with: completedItemsStartWith+toBeJournaledIndicator) || line.starts(with: incompleteItemsStartWith+toBeJournaledIndicator) {
            todoLineStatus.isMarkedForJournaling = true
        }
        
        return todoLineStatus
    }
    
    /**
     Takes an archive/journal file reprecented by an array of lines, and appends to the new array of lines after the header
     - parameter lines: the array of lines representing the current archive/journal
     - parameter withNewLines: the array of new lines to be archived/journaled
     - returns: a new array of lines representing the updated archive/journal file
     */
    public func prependArchive(lines: [String], withNewLines newLines: [String]) -> [String]? {
                
        var archiveLines = lines
        var blockEndsFound = 0
        let blockEndsString = "+++"
        for (index,line) in archiveLines.enumerated() {
            // move to end of header
            if line.starts(with: blockEndsString){
                blockEndsFound += 1
            }
            if blockEndsFound == 1 {
                if line.replacingOccurrences(of: " " , with: "").starts(with: "Date=") {
                    let now = Date()
                    let formatter = DateFormatter()
                    formatter.timeZone = TimeZone.current
                    formatter.dateFormat = "yyyy-MM-dd"
                    let date = formatter.string(from: now)
                    archiveLines[index] = "Date = \"\(date)\""
                }
            }
            if blockEndsFound == 2 {
                archiveLines.insert(contentsOf: newLines, at: index+1)
                
                return archiveLines
            }
        }

        // if we've gotten here, we've failed to prepend the archive lines
        return nil
    }
    
    /**
     Writes an updated archive/journal file, writes a timestamped backup copy of the original and logrotating oldest backup out
     - parameter filePath the path to the file you wish to write
     - parameter updatedContents: an array of strings representing the complete contents of the file
     */
    public func writeUpdatedFileAndArchive(atPath filePath: String, updatedContents: [String]) throws {
        
        // get the file name and path, create a backup filename
        let filename = URL(fileURLWithPath: filePath).lastPathComponent
        let path = URL(fileURLWithPath: filePath).deletingLastPathComponent()
        let backupPath = path.appendingPathComponent(backupRelativeFilePath)
        
        // create backup dir and age all backup copies (names) by one
        print("[INFO] [FileManager.default.createDirectory] \(backupPath.path) directory")
        do {
            try FileManager.default.createDirectory(atPath: backupPath.path, withIntermediateDirectories: true)
        } catch {
            print("[ERROR] could not create \(backupPath.path). Stop, do not work without backups!")
            return
        }
        let max = 5
        for i in (1...max).reversed() {
            print("[INFO] [FileManager.default.moveItem] \(backupPath.path)/\(i)-\(filename) to \(backupPath.path)/\(i+1)-\(filename)")
            do{
                try FileManager.default.moveItem(atPath: "\(backupPath.path)/\(i)-\(filename)", toPath: "\(backupPath.path)/\(i+1)-\(filename)")
            }catch{
                print("[ERROR] backup file rotation failure, non-critical if older backup files dont already exist.")
                print("[TODO] handle the case of missing backed up files, this is not a critical failure, move on.")
                print(error)
            }
        }
        // remove the retiring (rotated out by age) backup copy
        do {
            print("[INFO] [FileManager.default.removeItem] \(backupPath.path)/\(max+1)-\(filename)")
            try FileManager.default.removeItem(atPath: "\(backupPath.path)/\(max+1)-\(filename)")
        }catch{
            print(error)
        }
        // move the current todo file, making it the newest backup
        do {
            print("[INFO] [FileManager.default.moveItem] \(path.path)/\(filename) to \(backupPath.path)/1-\(filename)")
            try FileManager.default.moveItem(atPath: "\(path.path)/\(filename)", toPath: "\(backupPath.path)/1-\(filename)")
        }catch{
            print("[ERROR] FULL STOP! failed to move the current file into the backup dir! Do not overwrite the file with new data!")
            print(error)
            exit(1)
        }
        
        print("[INFO] [writeLinesTo] \(path.path)/\(filename) with file contents \(updatedContents)")
        writeLinesTo(pathToFile: "\(path.path)/\(filename)", fileLines: updatedContents)
    }
    
    /**
     Write [String] lines to a todo markdown file, and update the Hugo frontmatter header with the date of modification.
     - parameter pathToFile the name of the file to write to
     - parameter fileLines an array of Strings, each written to the file as a line of text
     */
    private func writeLinesTo(pathToFile: String, fileLines: [String]) {
        do {
            let fileText = fileLines.joined(separator: "\n")
            try fileText.write(to: URL(fileURLWithPath:pathToFile), atomically: false, encoding: .utf8)
        } catch {
            print("[ERROR] failed to write file \(pathToFile)")
            print(error)
        }
    }
    /**
     Reads a file and returns the contents as an array of Strings
     - parameter pathToNote: the path to the todo file
     - returns: an array of Strings representing the file contents
     */
    private func readLinesFrom(pathToNote: String) throws -> [String] {
        var fileContent = ""
        
        do {
            fileContent = try String(contentsOfFile: pathToNote)
        } catch {
            throw error
        }
        return fileContent.components(separatedBy: .newlines)
    }
    
}
