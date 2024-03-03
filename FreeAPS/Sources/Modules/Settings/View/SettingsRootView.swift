import HealthKit
import SwiftUI
import Swinject

extension Settings {
    struct RootView: BaseView {
        let resolver: Resolver
        @StateObject var state = StateModel()
        @State private var showShareSheet = false

        var body: some View {
            Form {
                Section {
                    Toggle("Closed loop", isOn: $state.closedLoop)
                }
                header: {
                    if let expirationDate = Bundle.main.profileExpiration {
                        Text(
                            "iAPS v\(state.versionNumber) (\(state.buildNumber))\nBranch: \(state.branch) \(state.copyrightNotice)" +
                                "\nBuild Expires: " + expirationDate
                        ).textCase(nil)
                    } else {
                        Text(
                            "iAPS v\(state.versionNumber) (\(state.buildNumber))\nBranch: \(state.branch) \(state.copyrightNotice)"
                        )
                    }
                }

                Section {
                    Text("Pump").navigationLink(to: .pumpConfig, from: self)
                    Text("CGM").navigationLink(to: .cgm, from: self)
                    Text("Watch").navigationLink(to: .watch, from: self)
                } header: { Text("Devices") }

                Section {
                    Text("Nightscout").navigationLink(to: .nighscoutConfig, from: self)
                    if HKHealthStore.isHealthDataAvailable() {
                        Text("Apple Health").navigationLink(to: .healthkit, from: self)
                    }
                    Text("Notifications").navigationLink(to: .notificationsConfig, from: self)
                } header: { Text("Services") }

                Section {
                    Text("Impostazioni microinfusore").navigationLink(to: .pumpSettingsEditor, from: self)
                    Text("Impostazioni basale").navigationLink(to: .basalProfileEditor, from: self)
                    Text("Insulin Sensitivities").navigationLink(to: .isfEditor, from: self)
                    Text("Carb Ratios").navigationLink(to: .crEditor, from: self)
                    Text("Target Glucose").navigationLink(to: .targetsEditor, from: self)
                } header: { Text("Configurazione") }

                Section {
                    Text("OpenAPS").navigationLink(to: .preferencesEditor, from: self)
                    Text("Autotune").navigationLink(to: .autotuneConfig, from: self)
                } header: { Text("OpenAPS") }

                Section {
                    Text("Icone app").navigationLink(to: .iconConfig, from: self)
                    Text("Impostazioni UI").navigationLink(to: .statisticsConfig, from: self)
                    Text("Calcolatore bolo").navigationLink(to: .bolusCalculatorConfig, from: self)
                    Text("ISF dinamica").navigationLink(to: .dynamicISF, from: self)
                    Text("Fat And Protein Conversion").navigationLink(to: .fpuConfig, from: self)
                    // Toggle("Animated Background", isOn: $state.animatedBackground)
                } header: { Text("Funzioni avanzate") }

                Section {
                    Toggle("Debug options", isOn: $state.debugOptions)
                    if state.debugOptions {
                        Group {
                            Text("Autosense")
                                .navigationLink(to: .configEditor(file: OpenAPS.Settings.autosense), from: self)
                            Text("Autotune")
                                .navigationLink(to: .configEditor(file: OpenAPS.Settings.autotune), from: self)
                            Text("Basal profile")
                                .navigationLink(to: .configEditor(file: OpenAPS.Settings.basalProfile), from: self)
                            Text("Logg: Glukos")
                                .navigationLink(to: .configEditor(file: OpenAPS.Monitor.glucose), from: self)
                            Text("Logg: Kalibreringar")
                                .navigationLink(to: .configEditor(file: OpenAPS.FreeAPS.calibrations), from: self)
                            Text("Logg: Kolhydrater")
                                .navigationLink(to: .configEditor(file: OpenAPS.Monitor.carbHistory), from: self)
                        }

                        Group {
                            Text("Logg: Måltid")
                                .navigationLink(to: .configEditor(file: OpenAPS.Monitor.meal), from: self)
                            Text("Logg: Pumphistorik")
                                .navigationLink(to: .configEditor(file: OpenAPS.Monitor.pumpHistory), from: self)
                            Text("Logg: Tillfälliga målvärden")
                                .navigationLink(to: .configEditor(file: OpenAPS.Settings.tempTargets), from: self)
                            Text("Målinställningar")
                                .navigationLink(to: .configEditor(file: OpenAPS.Settings.bgTargets), from: self)
                            Text("NS: Announcements")
                                .navigationLink(to: .configEditor(file: OpenAPS.FreeAPS.announcements), from: self)
                            Text("NS: Utförda Announcements")
                                .navigationLink(to: .configEditor(file: OpenAPS.FreeAPS.announcementsEnacted), from: self)
                        }

                        Group {
                            Text("NS: Ej uppladdade overrides")
                                .navigationLink(to: .configEditor(file: OpenAPS.Nightscout.notUploadedOverrides), from: self)
                            Text("Oref: Inställningar")
                                .navigationLink(to: .configEditor(file: OpenAPS.Settings.preferences), from: self)
                            Text("Oref: Middleware")
                                .navigationLink(to: .configEditor(file: OpenAPS.Middleware.determineBasal), from: self)
                            Text("Oref: Utfört")
                                .navigationLink(to: .configEditor(file: OpenAPS.Enact.enacted), from: self)
                            Text("Profilinställningar")
                                .navigationLink(to: .configEditor(file: OpenAPS.Settings.profile), from: self)
                            Text("Pumpinställningar")
                                .navigationLink(to: .configEditor(file: OpenAPS.Settings.settings), from: self)
                        }
                        Group {
                            Text("Pump profile")
                                .navigationLink(to: .configEditor(file: OpenAPS.Settings.pumpProfile), from: self)
                            Text("Statistics")
                                .navigationLink(to: .configEditor(file: OpenAPS.Monitor.statistics), from: self)
                            Text("Tillfälliga mål: Favoriter")
                                .navigationLink(to: .configEditor(file: OpenAPS.FreeAPS.tempTargetsPresets), from: self)
                            Text("Ändra inställningar (json)")
                                .navigationLink(to: .configEditor(file: OpenAPS.FreeAPS.settings), from: self)
                            HStack {
                                Text("Profil & inställningar")
                                Button(action: {
                                    let impactHeavy = UIImpactFeedbackGenerator(style: .heavy)
                                    impactHeavy.impactOccurred()
                                    state.uploadProfileAndSettings(true)
                                }) {
                                    HStack {
                                        Image(systemName: "icloud.and.arrow.up")
                                        Text("Nightscout ")
                                    }
                                }
                                .buttonStyle(DiscoButtonStyle())

                                .frame(maxWidth: .infinity, alignment: .trailing)
                                // .buttonStyle(.borderedProminent)
                            }
                            /* HStack {
                                 Text("Delete All NS Overrides")
                                 Button("Delete") { state.deleteOverrides() }
                                     .frame(maxWidth: .infinity, alignment: .trailing)
                                     .buttonStyle(.borderedProminent)
                                     .tint(.red)
                             } */
                            /* HStack {
                                Text("NS Test: Radera alla overrides")
                                Button("Delete") { state.deleteOverrides() }
                                     .frame(maxWidth: .infinity, alignment: .trailing)
                                     .buttonStyle(.borderedProminent)
                                     .tint(.red)
                             }

                             HStack {
                                 Text("NS Test: Radera senaste override")
                                 Button("Delete") { state.deleteOverride() }
                                     .frame(maxWidth: .infinity, alignment: .trailing)
                                     .buttonStyle(.borderedProminent)
                                     .tint(.red)
                             } */
                        }
                    }
                } header: { Text("Utvecklare") }

                // Section {
                // }

                Section {
                    Text("Share logs")
                        .onTapGesture {
                            showShareSheet = true
                        }
                }
            }
            .sheet(isPresented: $showShareSheet) {
                ShareSheet(activityItems: state.logItems())
            }
            .onAppear(perform: configureView)
            .navigationTitle("Settings")
            .navigationBarItems(trailing: Button("Close", action: state.hideSettingsModal))
            .navigationBarTitleDisplayMode(.inline)
            .onDisappear(perform: { state.uploadProfileAndSettings(false) })
        }
    }
}

struct DiscoButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(6)
            .background(
                AnyShapeStyle(
                    LinearGradient(colors: [
                        Color(red: 0.7215686275, green: 0.3411764706, blue: 1),
                        Color(red: 0.6235294118, green: 0.4235294118, blue: 0.9803921569),
                        Color(red: 0.4862745098, green: 0.5450980392, blue: 0.9529411765),
                        Color(red: 0.3411764706, green: 0.6666666667, blue: 0.9254901961),
                        Color(red: 0.262745098, green: 0.7333333333, blue: 0.9137254902)
                    ], startPoint: .leading, endPoint: .trailing)
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
