import SwiftUI

struct TempTargetsView: View {
    @EnvironmentObject var state: WatchStateModel

    var body: some View {
        if let until = state.tempTargets.compactMap(\.until).first, until > Date() {
            Button {
                WKInterfaceDevice.current().play(.click)
                state.enactTempTarget(id: "cancel")
            } label: {
                Text("Avsluta tf mål")
            }.font(.headline.weight(.semibold))
                .padding(.bottom)
                .padding(.top)
                .tint(.loopRed)
        }
        List {
            if state.tempTargets.isEmpty {
                Text("Set temp targets presets on iPhone first").padding()
            } else {
                ForEach(state.tempTargets) { target in
                    Button {
                        WKInterfaceDevice.current().play(.click)
                        state.enactTempTarget(id: target.id)
                    } label: {
                        VStack(alignment: .leading) {
                            HStack {
                                Text(target.name)
                                if let until = target.until, until > Date() {
                                    Spacer()
                                    Text(until, style: .timer).foregroundColor(.loopGreen)
                                }
                            }
                            Text(target.description).font(.caption2).foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
        .padding(.top, 10)
        .navigationTitle("Temp Targets")
    }
}

struct TempTargetsView_Previews: PreviewProvider {
    static var previews: some View {
        let model = WatchStateModel()
        model.tempTargets = [
            TempTargetWatchPreset(
                name: "Target 0",
                id: UUID().uuidString,
                description: "blablabla",
                until: Date().addingTimeInterval(60 * 60)
            ),
            TempTargetWatchPreset(name: "target1", id: UUID().uuidString, description: "blablabla", until: nil),
            TempTargetWatchPreset(name: "🤖 Target 2", id: UUID().uuidString, description: "blablabla", until: nil)
        ]
        return TempTargetsView().environmentObject(model)
    }
}
