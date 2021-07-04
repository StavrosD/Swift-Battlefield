#!/usr/bin/swift


import Foundation
// for an unknow reason getchar did not work correctly on my Mac so I adapted code from this ghist
// https://gist.github.com/thara/1b0e66f01170d78c3ca94bdd287289e1

let stdin = FileHandle.standardInput

var term = termios()

tcgetattr(stdin.fileDescriptor, &term)
term.c_lflag &= ~(UInt(ECHO | ICANON))  // Noecho & Noncanonical
tcsetattr(stdin.fileDescriptor, TCSAFLUSH, &term);

defer {
    tcsetattr(stdin.fileDescriptor, TCSAFLUSH, &term);
}

func readChar() -> UInt8 {
    var char: UInt8 = 0
    while read(stdin.fileDescriptor, &char, 1) == 1 { return char }
    return char
}

enum state : Character  {
    case empty = " "
    case emptyHit = "O"
    case ship = "S"
    case shipHit = "X"
}

class Ship { // I created a class beause it is easier to add functionality later
    let size : Int
    private var hits = 0
    private var startX  = 0
    private var startY = 0
    private var isVertical = false
    init(shipSize : Int, battlefield : inout [[state]], battlefieldSize : Int) {
        self.size = shipSize
        var intersect = true
        while intersect { // try to find a position inside the battlefield that does not intersect with another ship
            isVertical = Bool.random()  // select a random orientation
            intersect = false
            if isVertical {
                startX = Int.random(in: 0..<battlefieldSize - size)
                startY = Int.random(in: 0..<battlefieldSize)
                for counter in 0..<size { // test for intersection with other ship
                    if battlefield[startX + counter][startY] != state.empty { intersect = true }
                }
                if intersect == false {
                    for counter in 0..<size { // draw the ship
                        battlefield[startX + counter][startY] = state.ship
                    }
                }
            } else {
                startX = Int.random(in: 0..<battlefieldSize)
                startY = Int.random(in: 0..<battlefieldSize - size)
                for counter in 0..<size { // test for intersection with other ship
                    if battlefield[startX][startY + counter] != state.empty { intersect = true }
                }
                if intersect == false {
                    for counter in 0..<size { // draw the ship
                        battlefield[startX][startY+counter] = state.ship
                    }
                }
            }
        }
    } // end init
    
    func hit(x : Int, y : Int) -> Bool { // test if a hit at X,Y hits the ship
        if isVertical {
            if y != startY { return false }
            if !(startX..<startX + size).contains(x) { return false }
        } else {
            if x != startX { return false }
            if !(startY..<startY + size).contains(y) { return false }
        }
        hits+=1
        return true
    } // end func hit
    
    func sunk() -> Bool {
        hits == size
    } // end func sunk
} // end class Ship

class BattleField {
    var battleField : [[state]]
    var ships = [Ship]()
    let size : Int
    var shipsSunk = 0
    
    init(size : Int, shipSizes : [Int]) {
        self.size = size
        battleField = Array(repeating: Array(repeating: state.empty, count: size), count: size)
        for shipSize in shipSizes {
            ships.append(Ship(shipSize: shipSize, battlefield: &battleField, battlefieldSize: size))
        }
    }
    
    var finished : Bool {
        return shipsSunk == ships.count
    }
    
    func hit(x : Int, y : Int) -> Bool { // true if this is the first hit at this location, otherwise false
        switch battleField[x][y-1] {    // the user enters a number from 1 to 10 but the array is zero indexed so I have to subtract one
        case state.empty:
            battleField[x][y-1] = state.emptyHit
            return true
        case state.ship:
            for ship in ships {
                if ship.hit(x: x, y: y-1) {
                    battleField[x][y-1] = state.shipHit
                    if ship.sunk() {
                        shipsSunk += 1
                    }
                }
            }
            return true
        default:
            return false
        } // end switch battlefield[X][Y-1]
    }
    
    func printBattleField(debug : Bool = false){ // print the matrix
        print("\u{001B}[2J") // clear screen
        
        var separator = "   -"
        for _ in 1...4*size { separator += "-" }
        separator += "\n"
        
        var matrix = "   "
        for c in 1...battleField.count { // write header
            matrix += "  \(c) "
        }
        
        matrix += "\n"
        matrix += separator
        for row in 0..<battleField.count { // draw raw
            matrix += " \(Character(UnicodeScalar(65+row)!)) |"
            for column in 0..<battleField.count {
                matrix += " \( battleField[row][column].rawValue) |"
            }
            matrix += "\n" + separator
        }
        matrix += "\n"
        if !debug { matrix = matrix.replacingOccurrences(of: "S", with: " ")} // Hide ships when playing a game. If debug is set to true, the ships locations are vissible
        print(matrix)
    }
} // end class BattelField


// =============
// Program start
// =============
let debug = false
print("Press any key to start the game.")
let _ = readChar() // wait for key press
let size = 10 // set the size of the battlefield, size x size. Max 26 x 26 because there are 26 letters in the English alphabet.
let shipSizes = [2,3,3,4,5]  // set the ship sizes. On ship with size 2, two ships with size 3, one ship with size 4 and one ship with size 5

while true {
    let user = BattleField(size: size, shipSizes: shipSizes)
    let computer = BattleField(size: size, shipSizes: shipSizes)
    
    user.printBattleField(debug: debug)
    
    while !user.finished || !computer.finished {
        var hitResult = false
        
        // user plays first
        
        print("Player turn...")
        repeat {
            print("Enter a location to strike ie ‘A2’")
            var selection = readLine(strippingNewline: true)        // Read users input
            if !(selection?.first?.isLetter ?? true) { continue }   // The first character should be a letter
            if ( selection?.count ?? 0 ) == 0  { continue }         // the input should not be empty
            selection = selection?.uppercased()                     // convert to uppercase. There is no need to check for both lowercase and uppercase characters. For example, A or a indicate the same row
            let letter = selection!.removeFirst()                   // get the row number
            let X = Int(letter.asciiValue! - 65)                    // A = 0, B = 1, ...
            if X < 0 || X > size - 1 { continue }                   // there are only 10 rows
            if let Y = Int(selection ?? "-1") {                     // check if the
                if Y < 1 || Y > size  { continue }
                hitResult = user.hit(x: X, y: Y)
                if !hitResult { print("You have already tried that!") }
            }
        } while !hitResult
        user.printBattleField(debug: debug)
        if user.finished {
            print("You hit all ships! You win!")
            break
        }
        
        
        print("Computer turn...")
        repeat {
            hitResult = computer.hit(x: Int.random(in: 0..<size), y: Int.random(in: 1...size))
            if hitResult {
                if computer.finished { print("Computer hit all your ships! You lose!") }
            }
        } while !hitResult
    } // end while !user.finished || !computer.finished
    
    var char : UInt8 = 0
    while char != 121 && char != 110 && char != 89 && char != 78 { //ASCII y = 121 , n = 110, Y = 89, N = 78
        print("You have  destroyed all battleships. Would you like to play again? Y/N")
        char = readChar()
        
    }
    if char == 110 || char == 78 { break } // if n or N is pressed, terminate the application
} // end while / infinite loop


