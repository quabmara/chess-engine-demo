//
//  Evaluation.swift
//  chess ness
//
//  Created by mara on 24.02.24.
//

import Foundation

class EvaluationAndSearch {
    //piece values
    let pawnValue = 100
    let knightValue = 300
    let bishopValue = 300
    let rookValue = 500
    let queenValue = 900
    
    func getPieceValue(_ pieceType: String) -> Int {
        switch pieceType {
        case "p": return 300
        case "n": return 300
        case "b": return 300
        case "r": return 500
        case "q": return 900
        default: return 0
        }
    }
    
    func Evaluate(_ board: Board) -> Int {
        let whiteEvaluation = CountMaterial(0, board)
        let blackEvaluation = CountMaterial(1, board)
        
        let evaluation = whiteEvaluation - blackEvaluation
        
        let perspective = board.turnColor == "white" ? 1 : -1
        return evaluation * perspective
    }
    
    func CountMaterial(_ colorIndex: Int, _ board: Board) -> Int {
        var material = 0
        material += board.pawns[colorIndex].count * pawnValue
        material += board.knights[colorIndex].count * knightValue
        material += board.bishops[colorIndex].count * bishopValue
        material += board.rooks[colorIndex].count * rookValue
        material += board.queens[colorIndex].count * queenValue
        return material
    }
    
    func OrderMoves(_ moves: [Move], _ board: Board) -> [Int] {
        var scores: [Int] = []
        for move in moves {
            var moveScoreGuess = 0
            let movePieceType = getPieceType(board.square[move.StartSquare])
            let capturePieceType = getPieceType(board.square[move.TargetSquare])
            
            //prioritise capturing oppononet high value pieces with less value pieces
            if capturePieceType != "none" {
                moveScoreGuess = 10 * getPieceValue(capturePieceType) - getPieceValue(movePieceType)
            }
            
            //promoting pawn is good
            let rank = move.TargetSquare / 8
            let lastRank = board.turnColor == board.colorOfPlayer ? 0 : 7
            if movePieceType == "p" && rank == lastRank {
                moveScoreGuess += getPieceValue("q")
            }
            scores.append(moveScoreGuess)
        }
        return scores
    }
    
    func minmaxSearch(_ board: Board, _ depth: Int, _ bestMove: Move) -> Move? {
        if depth == 0 {
            return bestMove
        }
        
        let MoveObj = Moves()
        let moves: [Move] = MoveObj.GenerateLegalMoves(board)
        var scores: [Int] = OrderMoves(moves, board)
        
        for (i, move) in moves.enumerated() {
            let board2 = board //copy
            var newBestMove = bestMove
            
            board2.makeMove(move)
            if !MoveObj.KingInCheck(board2, board2.turnColor) {
                if minmaxSearch(board, depth - 1, bestMove) == nil {
                    break
                } else {
                    newBestMove = minmaxSearch(board, depth - 1, bestMove)!
                    board2.makeMove(newBestMove)
                }
            }
            
            board.setAllPiecePositions()
            let eveluation = Evaluate(board)
            if eveluation != 0 {
                scores[i] = eveluation
            }
            board2.undoMove(newBestMove)
            board2.undoMove(move)
        }
        print(scores)
        let bestmoveIndex = scores.firstIndex(of: scores.max() ?? 0) ?? 0
        return moves != [] ? moves[bestmoveIndex] : nil
    }
}
