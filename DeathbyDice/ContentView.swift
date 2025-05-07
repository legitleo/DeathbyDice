import SwiftUI

struct ContentView: View {
    @State private var isShowingRollScreen = false
    
    var body: some View {
        NavigationView {
            VStack {
                if !isShowingRollScreen {
                    // Splash Screen
                    VStack {
                        Text("Death by Dice")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .padding()
                        
                        Button(action: {
                            isShowingRollScreen = true
                        }) {
                            Text("Roll the Dice")
                                .font(.title2)
                                .padding()
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(10)
                        }
                    }
                } else {
                    // Roll Screen
                    RollScreen()
                }
            }
        }
    }
}

struct RollScreen: View {
    @State private var d6Result = 1
    @State private var d20Result = 1
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Dice Roll Results")
                .font(.title)
                .padding()
            
            HStack(spacing: 30) {
                VStack {
                    Text("D6")
                        .font(.headline)
                    Text("\(d6Result)")
                        .font(.system(size: 40))
                }
                
                VStack {
                    Text("D20")
                        .font(.headline)
                    Text("\(d20Result)")
                        .font(.system(size: 40))
                }
            }
            
            Button(action: rollDice) {
                Text("Roll Dice")
                    .font(.title2)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            .padding()
        }
    }
    
    func rollDice() {
        d6Result = Int.random(in: 1...6)
        d20Result = Int.random(in: 1...20)
    }
}

#Preview {
    ContentView()
} 