//
//  bots.swift
//  chess ness
//
//  Created by mara on 15.02.24.
//

import Foundation

let listOfBots = [Bot(name: "none"), Bot(name: "random"), NewBot(name: "minimax")]

class Bot: ObservableObject { //default bot random
    var name: String
    var possibleMoves: [Move] = []
    
    init(name: String) {
        self.name = name
    }
    
    func move(_ board: Board) -> Move? {
        return possibleMoves.randomElement()
    }
}

class NewBot: Bot {
    override func move(_ board: Board) -> Move? {
        let eval = EvaluationAndSearch()
        board.setAllPiecePositions()
        let move = eval.minmaxSearch(board, 2, Move(StartSquare: 0, TargetSquare: 0))
        //print(move)
        return move
    }
}
