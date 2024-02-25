//
//  board.swift
//  chess ness
//
//  Created by mara on 15.02.24.
//

import Foundation

//basic stuff
extension Dictionary where Value: Equatable {
    func findKey(forValue val: Value) -> Key? {
        return first(where: { $1 == val })?.key
    }
}

let pieceDict: [String:Int] = [
    "k": 1,
    "q": 2,
    "r": 3,
    "n": 4,
    "b": 5,
    "p": 6,
    "white": 8, //colors
    "black": 16,
]

func getPieceColor(_ piece: Int) -> String {
    if piece == 0 {
        return ""
    } else if piece < 16 {
        return "white"
    } else {
        return "black"
    }
}

func getPieceType(_ piece: Int) -> String {
    let colorInt = getPieceColor(piece) == "white" ? 8 : 16
    return pieceDict.findKey(forValue: piece - colorInt) ?? "error"
}

func pieceIsSlider(_ piece: Int) -> Bool {
    let pieceType = getPieceType(piece)
    return pieceType == "q" || pieceType == "r" || pieceType == "b"
}

class Board: ObservableObject {
    @Published var square: [Int] = Array(repeating: 0, count: 64)
    public var colorOfPlayer = "white"
    public var turnColor = "white"
    public var fenString = ""
    public var checkMate = false
    
    public var allMoves: [Move] = []
    public var capturedPieces: [Int] = []
    private var lastCapturedEnPassantSquares: [[Int]] = []
    public var pawnJumpingPiece = 100
    private var lastPromotions: [[Int]] = []
    
    public var castlingMovement: [Bool] = Array(repeating: true, count: 6) //0:wk, 1:wr1 (queenside), 2:wr2(kingside), 3:bk, 4:br1, 5:br2
    
    //opponent piecePosisitions
    public var opponentKing = 100
    public var opponentSliders: [Int] = []
    public var opponentKnights: [Int] = []
    public var opponentPawns: [Int] = []
    public var randomCount = 0
    
    //all piece positions 0: white 1: black
    public var pawns: [[Int]] = []
    public var bishops: [[Int]] = []
    public var knights: [[Int]] = []
    public var rooks: [[Int]] = []
    public var queens: [[Int]] = []
    
    func setDefaultBoard(fenStr: String) {
        loadPositionFromFen(fen: fenStr)
        
        setOpponentPiecePositions(turnColor)
        
        //reset stuff:
        allMoves = []
        checkMate = false
        lastCapturedEnPassantSquares = []
        lastPromotions = []
        pawnJumpingPiece = 100
        castlingMovement = Array(repeating: true, count: 6)
    }
    
    func loadPositionFromFen(fen: String) {
        //empty all squares
        square = Array(repeating: 0, count: 64)
        
        //read fenString
        var rank = 0
        var file = 0
        
        let fenBoard = fen.split(separator: " ")
        
        for char in fenBoard[0] {
            if char == "/" {
                file += 1
                rank = 0
            } else {
                if Int(String(char)) != nil {
                    rank += Int(String(char))!
                } else {
                    let pieceColor = char.isUppercase ? pieceDict["white"] : pieceDict["black"]
                    let pieceType = pieceDict[String(char).lowercased()]!
                    square[file * 8 + rank] = pieceColor! + pieceType
                    rank += 1
                }
            }
        }
        
        if fen.contains(" ") {
            let fenColorToMove = fen.split(separator: " ")[1]
            turnColor = fenColorToMove == "w" ? "white" : "black"
        }
        
        //castling
        //If neither side can castle, this is "-". Otherwise, this has one or more letters: "K" (White can castle kingside), "Q" (White can castle queenside), "k" (Black can castle kingside), and/or "q" (Black can castle queenside).
        if fenBoard.count >= 3 {
            let longString = fenBoard[2].count < 3 ? fenBoard[2] + fenBoard[3] : fenBoard[2]
            for char in longString {
                switch char {
                case "k":
                    castlingMovement[4] = false
                    castlingMovement[3] = false
                case "K":
                    castlingMovement[1] = false
                    castlingMovement[0] = false
                case "q":
                    castlingMovement[5] = false
                    castlingMovement[3] = false
                case "Q":
                    castlingMovement[2] = false
                    castlingMovement[0] = false
                case "-":
                    castlingMovement = Array(repeating: true, count: 6)
                    print("no castling")
                default:
                    castlingMovement = Array(repeating: false, count: 6)
                    print("castling allowed")
                }
            }
        }
        //print(castlingMovement, "atstart")
    }
    
    func setOpponentPiecePositions(_ color: String) {
        //reset
        opponentKing = 100
        opponentSliders = []
        opponentKnights = []
        opponentPawns = []
        //fill
        let colorInt = pieceDict[color]!
        for (i, squ) in square.enumerated() {
            if getPieceColor(squ) == color {
                if squ == pieceDict["k"]! + colorInt {
                    opponentKing = i
                } else if pieceIsSlider(squ) {
                    opponentSliders.append(i)
                } else if squ == pieceDict["n"]! + colorInt {
                    opponentKnights.append(i)
                } else if squ == pieceDict["p"]! + colorInt {
                    opponentPawns.append(i)
                }
            }
        }
    }
    
    func setAllPiecePositions() {
        //reset
        pawns = Array(repeating: [], count: 2)
        bishops = Array(repeating: [], count: 2)
        knights = Array(repeating: [], count: 2)
        rooks = Array(repeating: [], count: 2)
        queens = Array(repeating: [], count: 2)
        
        for (i, piece) in square.enumerated() {
            let colorIndex = getPieceColor(piece) == "white" ? 0 : 1
            switch getPieceType(piece) {
            case "p":
                pawns[colorIndex].append(i)
            case "b":
                bishops[colorIndex].append(i)
            case "n":
                knights[colorIndex].append(i)
            case "r":
                rooks[colorIndex].append(i)
            case "q":
                queens[colorIndex].append(i)
            default:
                break
            }
        }
    }
    
    func makeMove(_ move: Move?) {
        if move != nil {
            allMoves.append(move!)
            //set pawn jump
            pawnJumpingPiece = getPawnJump(move!) //default: 100
            
            //check if rook is captured -> castling movement
            isRookCaptured(move!)
            
            //make move
            //lastCaptured = square[move.TargetSquare]
            capturedPieces.append(square[move!.TargetSquare])
            square[move!.TargetSquare] = square[move!.StartSquare]
            square[move!.StartSquare] = 0
            
            //update board
            promotePawns(move!)
            finishCastlingMove(move!)
            removeEnPassantLeftoverPiece(move!)
            
            turnColor = turnColor == "white" ? "black" : "white"
            setOpponentPiecePositions(turnColor)
        }
    }
    
    func undoMove(_ move: Move) {
        allMoves = allMoves.filter { $0 != move }
        
        //reset pawn jump
        pawnJumpingPiece = getPawnJump(move) != 100 ? getLastPawnJumpingPiece() : 100
        
        //undo move
        square[move.StartSquare] = square[move.TargetSquare]
        square[move.TargetSquare] = capturedPieces[capturedPieces.endIndex - 1]
        
        //check if rook is captured -> castling movement
        isRookCaptured(move)
        
        //update board
        degradePawns(move)
        undoCastlingMove(move)
        addEnPassantLeftoverPiece(move)
        
        capturedPieces.removeLast()
            
        turnColor = turnColor == "white" ? "black" : "white"
        setOpponentPiecePositions(turnColor)
    }
    
    func promotePawns(_ move: Move) {
        let pawnDirectionIsUp = turnColor == colorOfPlayer
        let piece = square[move.TargetSquare]
        let rank = move.TargetSquare / 8
        if getPieceType(piece) == "p" && rank == (pawnDirectionIsUp ? 0 : 7) { //pawn on last rank
            lastPromotions.append([square[move.TargetSquare], move.TargetSquare])
            square[move.TargetSquare] = pieceDict["q"]! + pieceDict[turnColor]!
            //print("pawn promotion! ", pieceDict[turnColor]!, rank)
        }
    }
    
    func degradePawns(_ move: Move) {
        let pawnDirectionIsUp = turnColor == colorOfPlayer
        let rank = move.TargetSquare / 8
        let lastPromotionPawn = lastPromotions.popLast()
        if lastPromotionPawn != nil && rank == (pawnDirectionIsUp ? 7 : 0) { //pawn on last rank
            square[move.StartSquare] = lastPromotionPawn![0] //pieceDict["p"]! + oppositeColor
            square[lastPromotionPawn![1]] = capturedPieces[capturedPieces.endIndex - 1]
            //print(capturedPieces)
            //print("pawn degration! ")
        }
    }

    func removeEnPassantLeftoverPiece(_ move: Move) {
        if move.enPassant != nil {
            lastCapturedEnPassantSquares.append([move.enPassant!, square[move.enPassant!]])
            square[move.enPassant!] = 0
        }
    }
    
    func addEnPassantLeftoverPiece(_ move: Move) {
        if move.enPassant != nil {
            let lastCaptureSquare = lastCapturedEnPassantSquares.popLast()
            if lastCaptureSquare != nil {
                square[lastCaptureSquare![0]] = lastCaptureSquare![1]
            }
        }
    }
    
    func finishCastlingMove(_ move: Move) {
        let piece = square[move.TargetSquare]
        let moveDiff = (move.TargetSquare - move.StartSquare)
        let colorOffset = getPieceColor(piece) == "white" ? 0 : 3
        
        if getPieceType(piece) == "k" && abs(moveDiff) == 2 {
            if moveDiff < 0 { //queenside
                let rookSquare = move.TargetSquare - 2
                square[move.TargetSquare + 1] = square[rookSquare]
                square[rookSquare] = 0
                castlingMovement[colorOffset + 1] = true
            } else { //kingside
                let rookSquare = move.TargetSquare + 1
                square[move.TargetSquare - 1] = square[rookSquare]
                square[rookSquare] = 0
                castlingMovement[colorOffset + 2] = true
            }
            castlingMovement[colorOffset] = true
        }
    }
    
    func undoCastlingMove(_ move: Move) {
        let piece = square[move.StartSquare]
        let moveDiff = (move.TargetSquare - move.StartSquare)
        let colorOffset = getPieceColor(piece) == "white" ? 0 : 3
        
        if getPieceType(piece) == "k" && abs(moveDiff) == 2 {
            if moveDiff < 0 { //queenside
                let rookSquare = move.TargetSquare - 2
                square[rookSquare] = square[move.TargetSquare + 1]
                square[move.TargetSquare + 1] = 0
                castlingMovement[colorOffset + 1] = false
            } else { //kingside
                let rookSquare = move.TargetSquare + 1
                square[rookSquare] = square[move.TargetSquare - 1]
                square[move.TargetSquare - 1] = 0
                castlingMovement[colorOffset + 2] = false
            }
            castlingMovement[colorOffset] = false
        }
    }
    
    func getPawnJump(_ move: Move) -> Int {
        let piece = square[move.StartSquare]
        let moveDiff = abs((move.TargetSquare - move.StartSquare) / 8)
        if getPieceType(piece) == "p" && moveDiff == 2 {
            return move.TargetSquare
        }
        return 100
    }
    
    func getLastPawnJumpingPiece() -> Int {
        let moveBefore = allMoves[allMoves.endIndex - 2]
        return getPawnJump(moveBefore)
    }
    
    func isRookCaptured(_ move: Move) {
        let capturedPiece = square[move.TargetSquare]
        if getPieceType(capturedPiece) == "r" {
            let colorInt = getPieceColor(capturedPiece) == "white" ? 0 : 3
            let file = move.TargetSquare % 8
            let offset = file == 0 ? 1 : 2
            
            castlingMovement[colorInt + offset].toggle()
        }
    }
}
