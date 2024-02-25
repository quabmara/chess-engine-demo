import SwiftUI
import AVFoundation

struct FenStr {
    let name: String
    let fen: String
}
private var startFens = [
    FenStr(name: "start white", fen: "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq"),
    FenStr(name: "2", fen: "N2kbRR1/5p2/4P3/8/P1q2p2/4N1b1/p4pK1/4Q3 w - - 0 1"),
    FenStr(name: "3", fen: "8/8/8/1k6/4p3/8/2NP4/4KQ2 w - - 0 1"),
]

struct ContentView: View {
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    @StateObject var board = Board()
    @State private var newGameStarted = false
    @State var selectedBotIndex: Int = 0
    @State var selectedFenIndex: Int = 0
    @State var lastSelected: [Int] = []
    @State var explainSheetPresented = false
    
    let backgroundColor = Color(#colorLiteral(red: 0.8039215803, green: 0.8039215803, blue: 0.8039215803, alpha: 1))
    
    var body: some View {
        VStack {
            Spacer()
            Text("Chess v.1")
                .font(.title)
            Text("application for the swift student challenge 2024")
                .font(.caption)
                .bold()
            Text("mara lange")
                .font(.caption)
            HStack {
                Spacer()
                VStack(spacing: 5) {
                    //picker
                    HStack {
                        Text("selected bot:")
                        Picker("botselection", selection: $selectedBotIndex) {
                            ForEach((0...listOfBots.count - 1), id:\.self) { i in
                                Text(listOfBots[i].name)
                            }
                        }.pickerStyle(.menu)
                        Button(action: {
                            explainSheetPresented.toggle()
                        }) {
                            Image(systemName: "questionmark.circle")
                        }
                    }
                    HStack {
                        Text("start position:")
                        Picker("fen string", selection: $selectedFenIndex) {
                            ForEach((0...startFens.count - 1), id:\.self) { i in
                                Text(startFens[i].name)
                            }
                        }.pickerStyle(.menu)
                    }
                    Button("new game") {
                        lastSelected = []
                        board.setDefaultBoard(fenStr: startFens[selectedFenIndex].fen)
                        newGameStarted.toggle()
                        playSound()
                    }
                    
                    Text("Check Mate!")
                        .opacity(board.checkMate ? 1 : 0)
                    
                    BoardGraphic(board: board, selectedBot: listOfBots[selectedBotIndex], newGameStarted: $newGameStarted, lastSelected: $lastSelected)
                }
                Spacer()
            }
            Spacer()
        }
        .scaleEffect(horizontalSizeClass == .compact ? 1 : 1.5)
        .sheet(isPresented: $explainSheetPresented) { ExplainSheet(backgroundColor: backgroundColor) }
        .background(backgroundColor)
        .onAppear {
            board.setDefaultBoard(fenStr: startFens[selectedFenIndex].fen)
        }
    }
    func playSound() {
        buttonSoundEffect?.play()
    }
}

struct ExplainSheet: View {
    @Environment(\.dismiss) var dismiss
    let backgroundColor: Color
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 10) {
                    Text("Chess playground")
                        .font(.title)
                        .bold()
                        .padding(.top)
                    Text("This is a small chess engine demo.")
                        .font(.callout)
                    VStack(alignment: .leading, spacing: 8) {
                        Text("It has some basic functions, like Legal Move Generation and the use of the FEN notation to represent a starting chess position.")
                        Text("some things you can change (and have fun with):")
                                .bold()
                                .padding(.top)
                        Text("1 change the bot to play against \n   - simply a random opponent \n   - simple minmax search and evaluation algorithm \n   - yourself or a friend on the same device")
                        Text("2 explore some starting position \n   - classic starting position \n   - other positions to test out some trickier moves like pawn promotion and en passant")
                        Group {
                            Text("The images of the piece pictures are from wikipedia: ")
                                .padding(.top)
                            Text("https://commons.wikimedia.org/wiki/Category:SVG_chess_pieces#/media/File:Chess_Pieces_Sprite.svg")
                                .font(.system(size: 14))
                            Text("And the sounds are really professionally recorded and imported by me.")
                        }
                        Text("The project is named 'Chess v.1' (version one) because there is a lot of potential and plans to update it in the future with a more complex bot (search and evaluation algorithm). But sadly there wasn't enough time and too many bugs...")
                                .padding(.top)
                                .font(.callout)
                    }.padding(.top)
                    Text("much fun!")
                        .bold()
                    Spacer()
                }
            }
            .padding()
            .toolbar {
                Button("Done") {
                    dismiss()
                }
            }
        }
    }
}


struct BoardGraphic: View {
    @ObservedObject var board: Board
    @ObservedObject var selectedBot: Bot
    
    private let moves = Moves()
    
    @Binding var newGameStarted: Bool
    @State var possibleMoves: [Move] = []
    
    @State private var selected: Int = 100
    @Binding var lastSelected: [Int]
    
    let cellsize = 45.0
    let possibleMoveColor = Color(#colorLiteral(red: 1, green: 0.4363789825, blue: 0.3115835486, alpha: 1))
    let lastSelectedSquare = Color(#colorLiteral(red: 1, green: 0.7704771037, blue: 0.2463593623, alpha: 1))
    
    var body: some View {
        VStack(spacing: 0) {
            ForEach(0..<8) { file in
                HStack(spacing: 0) {
                    ForEach(0..<8) { rank in
                        let squareNumber = file * 8 + rank
                        let cellValue = board.square[squareNumber]
                        let playersTurn = board.turnColor == board.colorOfPlayer
                        
                        Button(action: {
                            if newGameStarted && !playersTurn && selectedBot.name != "none" {
                                print("here")
                                botMove()
                                newGameStarted = false
                            } else if newGameStarted {
                                possibleMoves = generatePossibleMoves()
                            }
                            if isValidSquare(possibleMoves, squareNumber, selected) && (selectedBot.name == "none" || playersTurn) { // move player's piece if legal
                                //player moves selected piece to new selected square
                                for move in possibleMoves {
                                    if move.StartSquare == selected && move.TargetSquare == squareNumber {
                                        makeMove(move)
                                        break
                                    }
                                }
                                updateLastSelected([selected, squareNumber])
                                
                                selected = squareNumber
                                
                                //now bot move
                                if selectedBot.name != "none" {
                                    botMove()
                                }
                            } else {
                                if selected == 100 { //select new square (if nothing selected)
                                    selected = file * 8 + rank
                                } else { // deselect square
                                    selected = 100
                                    //possibleMoves = []
                                }
                            }
                        }) {
                            ZStack {
                                let validSquare = isValidSquare(possibleMoves, squareNumber, selected)
                                let isColoredSquare = lastSelected.contains(squareNumber) || validSquare
                                
                                if cellValue != 0 {
                                    Rectangle()
                                        .frame(width: cellsize, height: cellsize)
                                        .foregroundStyle(getBgColor(selected, squareNumber, (file + rank) % 2 == 0))
                                    Rectangle()
                                        .frame(width: cellsize, height: cellsize)
                                        .foregroundStyle(validSquare ? possibleMoveColor : lastSelectedSquare)
                                        .opacity(getBgOpacity(isColoredSquare))
                                    //pieces
                                    Image(getImageName(cellValue))
                                        .resizable()
                                        .frame(width: cellsize, height: cellsize)
                                
                                } else {
                                    Rectangle()
                                        .frame(width: cellsize, height: cellsize)
                                        .foregroundStyle(getBgColor(selected, squareNumber, (file + rank) % 2 == 0))
                                    Rectangle()
                                        .frame(width: cellsize, height: cellsize)
                                        .foregroundStyle(validSquare ? possibleMoveColor : lastSelectedSquare)
                                        .opacity(getBgOpacity(isColoredSquare))
                                    //DEBUG
                                    //Text("\(file * 8 + rank)")
                                }
                            }
                        }
                            
                    }
                }
            }
        }.onAppear {
            //first bot move if bot is white
            if !(board.turnColor == board.colorOfPlayer) && selectedBot.name != "none" {
                botMove()
            } else {
                possibleMoves = generatePossibleMoves()
            }
            
            setSoundEffects()
            
            //TEST move generation
            //testMoveGeneration(depth: 3)
            //print(board.castlingMovement)
            //print(board.randomCount)
        }
    }
    
    func getImageName(_ number: Int) -> String {
        var color: String = ""
        if number < 16 {
            color = "white"
        } else {
            color = "black"
        }
        let type = pieceDict.findKey(forValue: number - pieceDict[color]!)
        return type! + "_" + color
    }
    func getType(_ number: Int) -> Int {
        var color: String = ""
        if number < 16 {
            color = "white"
        } else {
            color = "black"
        }
        return Int(number - pieceDict[color]!)
    }
    func getBgColor(_ selected: Int, _ squareNumber: Int, _ isLightSquare: Bool) -> Color {
        let lightColor = Color(#colorLiteral(red: 0.9411764706, green: 0.8509803922, blue: 0.7098039216, alpha: 1))
        let darkColor = Color(#colorLiteral(red: 0.7098039216, green: 0.5333333333, blue: 0.3882352941, alpha: 1))
        let selectionColor = Color(#colorLiteral(red: 1, green: 0.9294117647, blue: 0.4, alpha: 1))
        
        //DEBUG
//        let kingAttackedColor = Color(#colorLiteral(red: 0.1215686277, green: 0.01176470611, blue: 0.4235294163, alpha: 1))
//        if board.kingDangerSquares[squareNumber] == 1 {
//            return kingAttackedColor
//        }
        
        if selected == squareNumber {
            return selectionColor
        } else {
            return isLightSquare ? lightColor : darkColor
        }
    }
    func getBgOpacity(_ isLegalSquare: Bool) -> CGFloat {
        if isLegalSquare {
            return 0.4
        } else {
            return 0.0
        }
    }
    
    func isValidSquare(_ possibleMoves: [Move], _ squareNum: Int, _ selectedSquare: Int) -> Bool {
        for move in possibleMoves {
            if move.StartSquare == selectedSquare && move.TargetSquare == squareNum {
                //print(move)
                return true
            }
        }
        return false
    }
    
    func updateLastSelected(_ content: [Int]) {
        if lastSelected.count >= 2 {
            lastSelected.removeFirst(2)
        }
        lastSelected.append(contentsOf: content)
    }
    
    func generatePossibleMoves() -> [Move] {
        return moves.GenerateLegalMoves(board)
    }
    
    func makeMove(_ move: Move?) {
        playSound(move!)
        
        board.makeMove(move)
        if board.turnColor == board.colorOfPlayer || selectedBot.name == "none" {
            possibleMoves = generatePossibleMoves()
        } else {
            possibleMoves = []
        }
        if board.checkMate {
            print("check matesound")
            checkMateSoundEffect?.play()
        }
    }
    
    func botMove() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { //short delay
            selectedBot.possibleMoves = generatePossibleMoves()
            
            let botMove = selectedBot.move(board)
            makeMove(botMove)
            
            if botMove != nil {
                updateLastSelected([botMove!.TargetSquare, botMove!.StartSquare])
            }
            
            //deselect player selection
            selected = 100
        }
    }
    
    func playSound(_ move: Move) {
        //play sound
        if board.square[move.TargetSquare] != 0 { //capture sound
            captureSoundEffect?.play()
        } else { //normal move sound
            moveSoundEffect?.play()
        }
    }
    
    func testMoveGeneration(depth: Int) {
        print("running test: ")
        for i in 0...depth {
            print("at depth: \(i) result:", moves.MoveGenerationTest(board, i))
        }
    }
    
}


// sound effects
private var moveSoundEffect: AVAudioPlayer?
private var captureSoundEffect: AVAudioPlayer?
private var checkMateSoundEffect: AVAudioPlayer?
private var buttonSoundEffect: AVAudioPlayer?

func setSoundEffects() {
    let url1 = Bundle.main.url(forResource: "move", withExtension:"mp3")!
    let url2 = Bundle.main.url(forResource: "capture", withExtension:"mp3")!
    let url3 = Bundle.main.url(forResource: "check_mate", withExtension:"mp3")!
    let url4 = Bundle.main.url(forResource: "button", withExtension:"mp3")!
    
    do {
        moveSoundEffect = try AVAudioPlayer(contentsOf: url1)
        captureSoundEffect = try AVAudioPlayer(contentsOf: url2)
        checkMateSoundEffect = try AVAudioPlayer(contentsOf: url3)
        buttonSoundEffect = try AVAudioPlayer(contentsOf: url4)
    } catch {
        print("error while loading sound effects")
    }
}


