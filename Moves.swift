//
//  move.swift
//  chess ness
//
//  Created by mara on 15.02.24.
//

import Foundation

struct Move: Equatable {
    var StartSquare: Int
    var TargetSquare: Int
    var enPassant: Int?
}

class Moves: ObservableObject {
    var NumSquaresToEdge: [[Int]] = []
    
    func MoveGenerationTest(_ board: Board, _ depth: Int) -> Int {
        if depth == 0 {
            return 1
        }
        
        let board2 = board
        let moves: [Move] = GenerateLegalMoves(board2)
        var numPositions = 0
        
        for move in moves {
            board2.makeMove(move)
            if !KingInCheck(board2, board2.turnColor) {
                numPositions += MoveGenerationTest(board2, depth - 1)
            }
            board2.undoMove(move)
        }
        return numPositions
    }
    
    func GenerateLegalMoves(_ board: Board) -> [Move] {
        let friendlyColor = board.turnColor
        let pseudoLegalMoves: [Move] = GenerateMoves(board, friendlyColor)
        var legalMoves: [Move] = []
        
        for moveToVerify in pseudoLegalMoves {
            board.makeMove(moveToVerify)
            
            if !KingInCheck(board, friendlyColor) {
                legalMoves.append(moveToVerify)
            }
            
            board.undoMove(moveToVerify)
        }
        
        if legalMoves == [] {
            board.checkMate = true
            print("check mate")
        }
        
        return legalMoves
    }
    
    func GenerateMoves(_ board: Board, _ friendlyColor: String) -> [Move] {
        PrecomputedMoveData()
        var moves: [Move] = []
        for startSquare in 0..<64 {
            let piece = board.square[startSquare]
            if getPieceColor(piece) == friendlyColor {
                if pieceIsSlider(piece) { //queen, bishop, rook
                    moves.append(contentsOf: SlidingMoves(board, startSquare, piece, allAttacks: false))
                } else if getPieceType(piece) == "n" { //knight
                    moves.append(contentsOf: KnightMoves(board, startSquare, friendlyColor, allAttacks: false))
                } else if getPieceType(piece) == "p" { //pawn
                    moves.append(contentsOf: PawnMoves(board, startSquare, friendlyColor, allAttacks: false))
                } else if getPieceType(piece) == "k" { //king
                    moves.append(contentsOf: KingMoves(board, startSquare, friendlyColor, allAttacks: false))
                }
            }
        }
        return moves
    }
    
    //check funcs
    func KingInCheck(_ board: Board, _ friendlyColor: String) -> Bool {
        //calculate pieces that attack the king
        var attackers: [Move] = []
        let opponentColor = friendlyColor == "white" ? "black" : "white"
        let kingSquare = board.square.firstIndex(where: {$0 == (pieceDict["k"]! + pieceDict[friendlyColor]!)}) ?? 100
        
        if kingSquare == 100 {
            return true
        }
        
        let pieces = ["q", "b", "r", "n", "p"]
        for attackingPiece in pieces {
            let pieceInt = pieceDict[attackingPiece]! + pieceDict[opponentColor]!
            if pieceIsSlider(pieceInt) { //queen, bishop, rook
                let attackingMoves = SlidingMoves(board, kingSquare, pieceDict[attackingPiece]! + pieceDict[friendlyColor]!, allAttacks: true)
                attackers.append(contentsOf: isAttackingKing(attackingMoves, board, kingSquare, pieceInt, friendlyColor))
            } else if attackingPiece == "n" { //knight
                let attackingMoves = KnightMoves(board, kingSquare, friendlyColor, allAttacks: true)
                attackers.append(contentsOf: isAttackingKing(attackingMoves, board, kingSquare, pieceInt, friendlyColor))
            } else if attackingPiece == "p" { //pawn
                let attackingMoves = justPawnAttacks(board, kingSquare, friendlyColor, allAttacks: true)
                attackers.append(contentsOf: isAttackingKing(attackingMoves, board, kingSquare, pieceInt, friendlyColor))
            }
        }
        //print("attackers", attackers)
        return attackers != []
    }
    
    func isAttackingKing(_ attackingMoves: [Move], _ board: Board, _ kingSquare: Int, _ piece: Int, _ friendlyColor: String) -> [Move] {
        var attackers: [Move] = []
        
        for move in attackingMoves {
            if board.opponentSliders.contains(move.TargetSquare) && pieceIsSlider(piece) { //piece attacks king
                if board.square[move.TargetSquare] == piece {
                    attackers.append(Move(StartSquare: move.TargetSquare, TargetSquare: kingSquare))
                }
            } else if (board.opponentKnights.contains(move.TargetSquare) && getPieceType(piece) == "n") || (board.opponentPawns.contains(move.TargetSquare) && getPieceType(piece) == "p") {
                if board.square[move.TargetSquare] == piece {
                    attackers.append(Move(StartSquare: move.TargetSquare, TargetSquare: kingSquare))
                }
            }
        }
        return attackers
    }
    
    //move funcs
    func SlidingMoves(_ board: Board, _ startSquare: Int, _ piece: Int, allAttacks: Bool) -> [Move]{ //queen, bishop, rook
        var slideMoves: [Move] = []
        let DirectionOffsets: [Int] = [-8, 8, -1, 1, -9, 7, 9, -7]
        
        let friendlyColor = getPieceColor(piece)
        let opponentColor = friendlyColor == "white" ? "black" : "white"
        
        let pieceType = getPieceType(piece)
        let startDirIndex: Int = (pieceType == "b") ? 4 : 0
        let endDirIndex: Int = (pieceType == "r") ? 4 : 8
        
        for directionIndex in (startDirIndex..<endDirIndex) {
            for n in (0..<NumSquaresToEdge[startSquare][directionIndex]) {
                //print("di ", directionIndex)
                //print(NumSquaresToEdge[startSquare])
                let targetSquare: Int = startSquare + DirectionOffsets[directionIndex] * (n + 1)
                let pieceOnTargetSquare: Int = board.square[targetSquare]
                
                //blocked by friendly piece -> cannot move any further in this direction
                if getPieceColor(pieceOnTargetSquare) == friendlyColor {
                    if allAttacks { // one move more
                        slideMoves.append(Move(StartSquare: startSquare, TargetSquare: targetSquare))
                    }
                    //print("friend")
                    break
                }
                
                slideMoves.append(Move(StartSquare: startSquare, TargetSquare: targetSquare))
                
                //cannot move further in this direction after capture of opponent's piece
                if getPieceColor(pieceOnTargetSquare) == opponentColor {
                    //print("opponent")
                    break
                }
            }
        }
        
        return slideMoves
    }
    
    func KnightMoves(_ board: Board, _ startSquare: Int, _ friendlyColor: String, allAttacks: Bool) -> [Move] {
        var knightMoves: [Move] = []
        let horsejumps = [15, 17, 10, 6, -15, -17, -10, -6]
        
        for jump in horsejumps {
            if startSquare + jump < 64 && startSquare + jump >= 0 {
                let targetSquare: Int = startSquare + jump
                let pieceOnTargetSquare: Int = board.square[targetSquare]
                
                let colorTargetSquare = (targetSquare/8 + targetSquare%10) % 2 //light colored if true
                let colorStartSquare = (startSquare/8 + startSquare%10) % 2
                
                if ((getPieceColor(pieceOnTargetSquare) != friendlyColor) || allAttacks) && colorTargetSquare != colorStartSquare {
                    knightMoves.append(Move(StartSquare: startSquare, TargetSquare: targetSquare))
                }
                
            }
        }
        
        return knightMoves
    }
    
    func PawnMoves(_ board: Board, _ startSquare: Int, _ friendlyColor: String, allAttacks: Bool) -> [Move] {
        var pawnMoves: [Move] = []
        let DirectionOffsets: [Int] = [-8, 8, -1, 1, -9, 7, 9, -7]
        let pawnDirectionIsUp = friendlyColor == (board.colorOfPlayer == "white" ? "white" : "black")
        let rank = startSquare / 8
        let end_rank = pawnDirectionIsUp ? 0 : 7
        let loop = (rank == abs(end_rank - 6)) ? 2 : 1 //special skip rule at beginning (6 : 1 rank)
        var targetSquare: Int = 64
        let dIndeces = [4, 7, 0, 6, 5, 1]

        
        if rank != end_rank { //at other end -> promotion (in contentview because board change)
            //forward move
            for n in (0..<loop) {
                let offset = pawnDirectionIsUp ? (DirectionOffsets[dIndeces[2]] * (n + 1)) : -(DirectionOffsets[dIndeces[2]] * (n + 1))
                targetSquare = startSquare + offset
                
                let pieceOnTargetSquare: Int = board.square[targetSquare]
                
                if pieceOnTargetSquare == 0 { //no piece blocks -> can move further
                    pawnMoves.append(Move(StartSquare: startSquare, TargetSquare: targetSquare))
//                    if abs(offset) == 16 {
//                        print("skippididu")
//                    }
                }
            }
            
            //diagonal attack
            pawnMoves.append(contentsOf: justPawnAttacks(board, startSquare, friendlyColor, allAttacks: false))
        }
        return pawnMoves
    }
    
    func justPawnAttacks(_ board: Board, _ startSquare: Int, _ friendlyColor: String, allAttacks: Bool) -> [Move] {
        var pawnAttacks: [Move] = []
        let DirectionOffsets: [Int] = [-8, 8, -1, 1, -9, 7, 9, -7]
        let opponentColor = friendlyColor == "white" ? "black" : "white"
        let pawnDirectionIsUp = friendlyColor == board.colorOfPlayer
        let rank = startSquare / 8
        let dIndeces = [4, 7, 0, 6, 5, 1]
        let startIndex = pawnDirectionIsUp ? 0 : 3
        
        //diagonal attack
        for n in startIndex..<(startIndex + 2) {
            if NumSquaresToEdge[startSquare][dIndeces[n]] > 0 { // no wall
                let targetSquare = startSquare + DirectionOffsets[dIndeces[n]]
                
                let pieceOnTargetSquare: Int = board.square[targetSquare]
                
                //opponent piece is on targetSquare -> can attack opponent piece
                if (pieceOnTargetSquare != 0 && getPieceColor(pieceOnTargetSquare) == opponentColor) {
                    pawnAttacks.append(Move(StartSquare: startSquare, TargetSquare: targetSquare))
                    //print(startSquare, targetSquare)
                }
                
                //opponent is on neighboring square and correct rank -> en passant
                let amount = pawnDirectionIsUp ? 3 : 4
                let neighborOffset = [-1, 1]
                
                if rank == amount { //correct rank
                    for i in (0...1) {
                        let neighborSquare = startSquare + neighborOffset[i]
                        let pieceOnNeighborSquare = board.square[neighborSquare]
                        
                        //print(pieceOnNeighborSquare, pieceDict["p"]! + pieceDict[opponentColor]!)
                        if pieceOnNeighborSquare == pieceDict["p"]! + pieceDict[opponentColor]! { //opponent neighbor
                            //neighborPiece did pawnjump last move
                            //print(neighborSquare, board.pawnJumpingPiece)
                            if neighborSquare == board.pawnJumpingPiece {
                                let moveDirection = pawnDirectionIsUp ? -8 : 8
                                
                                pawnAttacks.append(Move(StartSquare: startSquare, TargetSquare: neighborSquare + moveDirection, enPassant: neighborSquare))
                                
                            }
                        }
                    }
                }
            }
        }
        return pawnAttacks
    }
    
    func KingMoves(_ board: Board, _ startSquare: Int, _ friendlyColor: String, allAttacks: Bool) -> [Move] {
        var kingMoves: [Move] = []
        
        let DirectionOffsets: [Int] = [-8, 8, -1, 1, -9, 7, 9, -7]
        for directionIndex in (0..<8) {
            if NumSquaresToEdge[startSquare][directionIndex] > 0 { // no wall
                let targetSquare: Int = startSquare + DirectionOffsets[directionIndex]
                let pieceOnTargetSquare: Int = board.square[targetSquare]
                
                //no friendly piece on targetSquare
                if ((getPieceColor(pieceOnTargetSquare) != friendlyColor) || allAttacks) {
                    kingMoves.append(Move(StartSquare: startSquare, TargetSquare: targetSquare))
                }
            }
        }
        
        //castling
        let oppositeColor = friendlyColor == "white" ? "black" : "white"
        board.setOpponentPiecePositions(oppositeColor)
        if !KingInCheck(board, friendlyColor) {
            let colorIndex = friendlyColor == "white" ? 0 : 3
            let offsets = [-2, 2]
            for i in (1...2) {
                if !board.castlingMovement[colorIndex] && (!board.castlingMovement[colorIndex + i]) {
                    let targetSquare = startSquare + offsets[i - 1]
                    let pieceOnTargetSquare: Int = board.square[targetSquare]
                    let queensideCastle = NumSquaresToEdge[startSquare][i + 1] == 4
                    var blockingPiece = false
                    
                    //check blocking pieces
                    if board.square[targetSquare - 1] != 0 {
                        blockingPiece = true
                    }
                    if queensideCastle && board.square[targetSquare + 1] != 0 {
                        blockingPiece = true
                    }
                    
                    //no piece on targetSquare + no in between piece
                    if pieceOnTargetSquare == 0 && !blockingPiece {
                        kingMoves.append(Move(StartSquare: startSquare, TargetSquare: targetSquare))
                    }
                }
            }
        }
        
        return kingMoves
    }
    
    func PrecomputedMoveData() {
        NumSquaresToEdge = Array(repeating: [], count: 64)
        for file in (0..<8) {
            for rank in (0..<8) {
                let numNorth = file
                let numSouth = 7 - file
                let numWest = 7 - rank
                let numEast = rank
                
                let squareIndex = file * 8 + rank
                NumSquaresToEdge[squareIndex] = [
                    numNorth,
                    numSouth,
                    numEast,
                    numWest,
                    min(numNorth, numEast),
                    min(numSouth, numEast),
                    min(numSouth, numWest),
                    min(numNorth, numWest),
                ]
                
            }
        }
    }
}
