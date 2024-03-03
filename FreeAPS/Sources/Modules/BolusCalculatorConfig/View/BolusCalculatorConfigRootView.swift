import SwiftUI
import Swinject

extension BolusCalculatorConfig {
    struct RootView: BaseView {
        let resolver: Resolver
        @StateObject var state = StateModel()

        private var conversionFormatter: NumberFormatter {
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            formatter.maximumFractionDigits = 1

            return formatter
        }

        private var formatter: NumberFormatter {
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            return formatter
        }

        var body: some View {
            Form {
                Section {
                    HStack {
                        Toggle("Attiva calcolatore bolo", isOn: $state.useCalc)
                    }
                    if state.useCalc {
                        HStack {
                            Toggle("Visualizzazione dati e calcoli", isOn: $state.advancedCalc)
                        }
                        HStack {
                            Text("Fattore regolazione")
                            Spacer()
                            DecimalTextField("0.8", value: $state.overrideFactor, formatter: conversionFormatter)
                        }
                    }
                    if !state.useCalc {
                        HStack {
                            Text("Fattore regolazione")
                            DecimalTextField("", value: $state.insulinReqPercentage, formatter: formatter)
                        }
                    }
                } header: { Text("Impostazioni calcolatore") }

                if state.useCalc {
                    Section {
                        HStack {
                            Toggle("Pasti ricchi di grassi", isOn: $state.fattyMeals)
                        }
                        HStack {
                            Text("Fattore regolazione")
                            Spacer()
                            DecimalTextField("0.7", value: $state.fattyMealFactor, formatter: conversionFormatter)
                        }
                        HStack {
                            Text("attiva automaticamente se i grassi e le proteine nel pasto sono superiori a")
                            Spacer()
                            DecimalTextField("0.5", value: $state.fattyMealTrigger, formatter: conversionFormatter)
                        }
                    } header: { Text("Pasti ricchi di grassi e proteine") }
                }

                if state.useCalc {
                    Section {
                        HStack {
                            Toggle("attiva superbolus", isOn: $state.sweetMeals)
                        }
                        HStack {
                            Text("Numero di ore basali nel superbolo")
                            Spacer()
                            DecimalTextField("2", value: $state.sweetMealFactor, formatter: conversionFormatter)
                        }
                    } header: { Text("Superbolus") }
                }

                Section(
                    footer: Text(
                        "Qui puoi scegliere di utilizzare il nuovo calcolatore del bolo invece dei normali calcoli del bolo di iAPS. \n\nIl fattore del bolo manuale (predefinito 0,8) viene utilizzato per limitare la proporzione del fabbisogno totale di insulina calcolato dal calcolatore che dovrebbe essere raccomandato come bolo.\n\nIl fattore per i pasti ad alto contenuto di grassi (predefinito 0,7) aggiunge un'altra restrizione alla raccomandazione del bolo per tenere conto di un tempo di assorbimento più lungo.\n\n Successivamente, un fattore per la proporzione di grassi + proteine in un pasto registrato che dovrebbe innescare l'attivazione del fattore per i pasti ad alto contenuto di grassi (predefinito 0,5).\n\nInfine La capacità di dare il superbolo può essere attivata. Il superbolo aumenta il calcolo del bolo con il basale programmato corrispondente al numero di ore specificato nell'impostazione per questo (default 2)"
                    )
                )
                    {}
            }
            .onAppear(perform: configureView)
            .navigationBarTitle("Calcolatore bolo")
            .navigationBarTitleDisplayMode(.automatic)
        }
    }
}
