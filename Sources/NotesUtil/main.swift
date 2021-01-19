import NotesUtilTools
import Foundation


/**
 CLI begins
 */
let args = CommandLine.arguments

if args.count < 2 {
    print("[NotesUtil]")
    print("you must supply a file name argument")
    exit(1)
}

let sourceFile = args[1]
print("will process \(sourceFile)\n")

let nut = NotesUtilTools()

main(sourceFile: sourceFile)

/**
 CLI ends
 */

func main(sourceFile: String) {
    do {
        try nut.processTodoFile(pathToNote: sourceFile)
    } catch {
        print(error)
        exit(1)
    }
    exit(0)
}

