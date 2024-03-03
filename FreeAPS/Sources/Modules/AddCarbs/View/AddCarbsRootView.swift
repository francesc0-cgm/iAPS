import CoreData
import SwiftUI
import Swinject
import WebKit

extension AddCarbs {
    // WebViewRepresentable to wrap a WKWebView
    struct WebViewRepresentable: UIViewControllerRepresentable {
        let urlString: String

        func makeUIViewController(context: Context) -> UIViewController {
            let viewController = UIViewController()
            let webView = WKWebView()
            webView.navigationDelegate = context.coordinator
            viewController.view = webView

            if let url = URL(string: urlString) {
                let request = URLRequest(url: url)
                webView.load(request)
            }

            return viewController
        }

        func updateUIViewController(_: UIViewController, context _: Context) {}

        func makeCoordinator() -> Coordinator {
            Coordinator(self)
        }

        class Coordinator: NSObject, WKNavigationDelegate {
            var parent: WebViewRepresentable

            init(_ parent: WebViewRepresentable) {
                self.parent = parent
            }
        }
    }

    struct RootView: BaseView {
        let resolver: Resolver
        let editMode: Bool
        let override: Bool
        @StateObject var state = StateModel()
        @State var dish: String = ""
        @State var isPromptPresented = false
        @State private var note: String = ""
        @State private var showInfo = false
        @State var saved = false
        @State var pushed = false
        @State private var showAlert = false
        @State private var isTapped: Bool = false
        @FocusState private var isFocused: Bool

        @Environment(\.colorScheme) var colorScheme

        @FetchRequest(
            entity: Presets.entity(),
            sortDescriptors: [NSSortDescriptor(key: "dish", ascending: true)]
        ) var carbPresets: FetchedResults<Presets>

        @Environment(\.managedObjectContext) var moc

        private var formatter: NumberFormatter {
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            formatter.maximumFractionDigits = 1
            return formatter
        }

        var body: some View {
            Form {
                if state.isEnabled {
                    Section {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                                .padding(.trailing, 8)
                            Text(
                                "En aktiv override modifierar just nu din insulinkänslighet och/eller kolhydratskvot. \nOm du inte vill att detta ska påverka hur insulindosen beräknas för måltiden bör du stänga av overriden innan du fortsätter."
                            )
                            .font(.caption).foregroundColor(.secondary)
                        }
                        .onTapGesture(perform: { state.showModal(for: .overrideProfilesConfig)
                        })
                    }
                }

                if let carbsReq = state.carbsRequired, state.carbs < carbsReq {
                    Section {
                        HStack {
                            Text("Carbs required").foregroundColor(.orange)
                            Spacer()
                            Text((formatter.string(from: carbsReq as NSNumber) ?? "") + " gram").foregroundColor(.orange)
                                .gesture(TapGesture().onEnded {
                                    self.isTapped.toggle()
                                    if isTapped {
                                        state.carbs = carbsReq
                                    }
                                })
                        }
                    }
                }

                // Summary when combining presets
                if state.waitersNotepad() != "" {
                    Section(header: Text("Preferiti selezionati")) {
                        ScrollView(.horizontal, showsIndicators: false) {
                            let test = state.waitersNotepad().components(separatedBy: ", ").removeDublicates()
                            HStack(spacing: 0) {
                                ForEach(test, id: \.self) {
                                    Text($0).foregroundStyle(Color.randomVibrantColor()).font(.footnote)
                                    Text($0 == test[test.count - 1] ? "" : " • ")
                                }
                            }.frame(maxWidth: .infinity, alignment: .center)
                        }
                    }
                }

                Section {
                    HStack {
                        Text("Carbs").fontWeight(.semibold)
                        Spacer()
                        DecimalTextField(
                            "0",
                            value: $state.carbs,
                            formatter: formatter,
                            autofocus: true,
                            cleanInput: true
                        )
                        Text("grams").fontWeight(.semibold)
                    }
                    .listRowBackground(Color(.loopYellow).opacity(0.8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 11) // Adjust the corner radius as needed
                            .stroke(lineWidth: 7)
                            .padding(.leading, -16)
                            .padding(.trailing, -16)
                            .padding(.top, -4)
                            .padding(.bottom, -4)
                            .foregroundColor(colorScheme == .dark ? .primary : .white)
                    )

                    if state.useFPUconversion {
                        proteinAndFat()
                    }
                }
                Section {
                    mealPresets

                    HStack {
                        if state.selection != nil && state.useFPUconversion {
                            Button { showAlert.toggle() }

                            label: {
                                Image(systemName: "trash")
                                // .offset(x: 5, y: 0)
                                Text("Cancella preferito")
                            }
                            .frame(alignment: .leading)
                            .disabled(state.selection == nil)
                            .accentColor(.loopRed)
                            .buttonStyle(BorderlessButtonStyle())
                            .controlSize(.mini)
                            .alert(
                                "Cancella preferito '\(state.selection?.dish ?? "")'?",
                                isPresented: $showAlert,
                                actions: {
                                    Button("No", role: .cancel) {}
                                    Button("Yes", role: .destructive) {
                                        state.deletePreset()

                                        state.carbs += ((state.selection?.carbs ?? 0) as NSDecimalNumber) as Decimal
                                        state.fat += ((state.selection?.fat ?? 0) as NSDecimalNumber) as Decimal
                                        state.protein += ((state.selection?.protein ?? 0) as NSDecimalNumber) as Decimal

                                        // Handle note addition here
                                        state.note = state.selection?.note ?? "" // Set state.note to the selected note

                                        state.addPresetToNewMeal()
                                    }
                                }
                            )
                        } else
                        {
                            Button {
                                isPromptPresented = true
                            }
                            label: {
                                Text("Preferiti") }
                                .frame(alignment: .leading)
                                .controlSize(.mini)
                                .buttonStyle(BorderlessButtonStyle())
                                .foregroundColor(
                                    (state.carbs <= 0 && state.fat <= 0 && state.protein <= 0) ||
                                        (
                                            (((state.selection?.carbs ?? 0) as NSDecimalNumber) as Decimal) == state
                                                .carbs && (((state.selection?.fat ?? 0) as NSDecimalNumber) as Decimal) ==
                                                state
                                                .fat && (((state.selection?.protein ?? 0) as NSDecimalNumber) as Decimal) ==
                                                state
                                                .protein
                                        ) ? Color(.systemGray2) : Color(.systemBlue)
                                )
                                .disabled(
                                    (state.carbs <= 0 && state.fat <= 0 && state.protein <= 0) ||
                                        (
                                            (((state.selection?.carbs ?? 0) as NSDecimalNumber) as Decimal) == state
                                                .carbs && (((state.selection?.fat ?? 0) as NSDecimalNumber) as Decimal) ==
                                                state
                                                .fat && (((state.selection?.protein ?? 0) as NSDecimalNumber) as Decimal) ==
                                                state
                                                .protein
                                        )
                                )
                        }
                        Spacer()
                        Button {
                            state.useFPUconversion.toggle()
                        }
                        label: {
                            Text(
                                state.useFPUconversion ? NSLocalizedString("Nascondi", comment: "") :
                                    NSLocalizedString("Mostra", comment: "")
                            )
                            .foregroundColor(.accentColor)
                            Image(
                                systemName: state.useFPUconversion ? "chevron.up.circle" : "chevron.down.circle"
                            )
                            .foregroundColor(.accentColor)
                        }
                        .controlSize(.mini)
                        .buttonStyle(BorderlessButtonStyle())
                    }
                    .popover(isPresented: $isPromptPresented) {
                        presetPopover
                    }
                }

                Section {
                    let maxamountcarbs = Double(state.maxCarbs)
                    let formattedMaxAmountCarbs = String(format: "%.0f", maxamountcarbs)
                    Button {
                        if state.carbs <= state.maxCarbs {
                            // Only allow button click if carbs are below maxCarbs
                            state.add(override, fetch: editMode)
                        }
                    } label: {
                        HStack {
                            if state.carbs > state.maxCarbs || state.fat > state.maxCarbs || state.protein > state.maxCarbs {
                                Image(systemName: "x.circle.fill")
                                    .foregroundColor(.loopRed)
                            }
                            Text(
                                (state.skipBolus && !override && !editMode) ? "Save" :
                                    (
                                        (
                                            state.carbs <= state.maxCarbs && state.fat <= state.maxCarbs && state
                                                .protein <= state
                                                .maxCarbs
                                        ) ?
                                            "Continua" :
                                            "Imposta limite massimo: \(formattedMaxAmountCarbs)g"
                                    )
                            )
                            .fontWeight(.semibold)
                            .font(.title3)
                        }
                    }
                    .disabled(
                        state.carbs <= 0 && state.fat <= 0 && state.protein <= 0 || state.carbs > state.maxCarbs || state
                            .fat > state.maxCarbs || state.protein > state.maxCarbs
                    )
                    .listRowBackground(
                        (state.carbs <= 0 && state.fat <= 0 && state.protein <= 0) ||
                            state.carbs > state.maxCarbs ||
                            state.fat > state.maxCarbs ||
                            state.protein > state.maxCarbs
                            ? AnyView(Color(.systemGray4))
                            : AnyView(LinearGradient(
                                gradient: Gradient(colors: [
                                    Color(red: 0.7215686275, green: 0.3411764706, blue: 1),
                                    Color(red: 0.6235294118, green: 0.4235294118, blue: 0.9803921569),
                                    Color(red: 0.4862745098, green: 0.5450980392, blue: 0.9529411765),
                                    Color(red: 0.3411764706, green: 0.6666666667, blue: 0.9254901961),
                                    Color(red: 0.262745098, green: 0.7333333333, blue: 0.9137254902)
                                ]),
                                startPoint: .leading,
                                endPoint: .trailing
                            ))
                    )
                    .tint(.white)
                    .frame(maxWidth: .infinity, alignment: .center)
                }
            }

            .onAppear {
                configureView {
                    state.loadEntries(editMode)
                }
                state.savedSettings()
            }
            // .onAppear { state.savedSettings() }
            .sheet(isPresented: $showInfo) {
                webCarbCalculator
            }
            .navigationTitle("Pasto")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                leading: Button {
                    showInfo.toggle()
                }
                label: {
                    Image(systemName: "list.bullet.circle")
                        .scaleEffect(0.61)
                        .font(Font.title.weight(.semibold))
                        .offset(x: -11, y: 0)
                    Text("Conta CHO")
                        .offset(x: -22, y: 0)
                },
                trailing: Button { state.hideModal() }
                label: { Text("Cancel") }
            )
        }

        var webCarbCalculator: some View {
            NavigationView {
                ScrollView {
                    ZStack(alignment: .top) {
                        VStack {
                            HStack {
                                Spacer()
                                HStack {
                                    Text("Insulin sensitive")
                                        .foregroundColor(.secondary)
                                        .offset(x: 4)
                                    Text(state.carbRatio.formatted())
                                        .fontWeight(.semibold)
                                    Text("mg/dl/U")
                                        .foregroundColor(.secondary)
                                        .offset(x: -6)
                                        .padding(.trailing, 10)
                                }
                                HStack {
                                    Text("Carboidrati attivi")
                                        .foregroundColor(.secondary)
                                        .offset(x: 4)
                                    Text(state.cob.formatted())
                                        .fontWeight(.semibold)
                                    Text("g")
                                        .foregroundColor(.secondary)
                                        .offset(x: -6)
                                }
                                Spacer()
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 10)
                            .font(.footnote)
                            .frame(height: 40)
                            .background(Color(.systemBackground))
                            Spacer()
                        }
                        .zIndex(1)
                        VStack {
                            // Use WebViewRepresentable to display the webpage
                            WebViewRepresentable(
                                urlString: state.carbsUrl
                            )
                            .frame(height: 660)
                            Spacer()
                            VStack {
                                Spacer()
                            }
                            .frame(height: 350)
                        }
                        .zIndex(0)
                    }

                    .navigationBarTitle("Conta CHO")
                    .navigationBarTitleDisplayMode(.inline)
                    .navigationBarItems(
                        leading:
                        HStack {
                            Button(action: {
                                showInfo.toggle()
                            }) {
                                Image(systemName: "chevron.left")
                                    .scaleEffect(0.61)
                                    .font(Font.title.weight(.semibold))
                                    .offset(x: -13, y: 0)
                                Text("Pasto")
                                    .offset(x: -22, y: 0)
                            }
                        },
                        trailing:
                        HStack {
                            Button {
                                UIApplication.shared.open(
                                    URL(
                                        string: "https://soknaringsinnehall.livsmedelsverket.se"
                                    )!,
                                    options: [:],
                                    completionHandler: nil
                                )
                            }
                            label: {
                                Image(systemName: "magnifyingglass")
                            }
                        }
                    )
                }
            }
            .onDisappear {
                state.updateCurrentDate() // Daniel: Added to update the date in the datepicker when leaving räkna KH web view
            }
        }

        var presetPopover: some View {
            Form {
                Section {
                    TextField("Name Of Dish", text: $dish)
                        .onAppear {
                            // Set initial text of the TextField
                            if !state.note.isEmpty {
                                dish = state.note
                            }
                        }

                    Button {
                        saved = true
                        if dish != "", saved {
                            let preset = Presets(context: moc)
                            preset.dish = dish
                            preset.fat = state.fat as NSDecimalNumber
                            preset.protein = state.protein as NSDecimalNumber
                            preset.carbs = state.carbs as NSDecimalNumber

                            // Set the note property
                            preset.note = state.note

                            try? moc.save()
                            state.addNewPresetToWaitersNotepad(dish)
                            saved = false
                            isPromptPresented = false
                        }
                    } label: {
                        Text("Save")
                    }

                    Button {
                        dish = ""
                        saved = false
                        isPromptPresented = false
                    } label: {
                        Text("Cancel")
                    }
                } header: {
                    Text("Preferiti")
                }
            }
        }

        private var mealPresets: some View {
            Section {
                HStack {
                    Picker("", selection: $state.selection) {
                        Text("Sel. Preferito").tag(nil as Presets?)
                        ForEach(carbPresets, id: \.self) { (preset: Presets) in
                            Text(preset.dish ?? "").tag(preset as Presets?)
                        }
                    }
                    .labelsHidden()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    // .pickerStyle(.automatic)
                    .foregroundColor(.primary)
                    .offset(x: -12, y: 0)
                    ._onBindingChange($state.selection) { _ in
                        state.carbs += ((state.selection?.carbs ?? 0) as NSDecimalNumber) as Decimal
                        state.fat += ((state.selection?.fat ?? 0) as NSDecimalNumber) as Decimal
                        state.protein += ((state.selection?.protein ?? 0) as NSDecimalNumber) as Decimal
                        state.note = state.selection?.note ?? "" // Set state.note to the selected note
                        state.addToSummation()
                    }
                    .onChange(of: state.carbs) { newValue in
                        // Check if the value is zero and update the selection accordingly
                        if newValue == 0 {
                            state.selection = nil
                        }
                    }
                    if state.selection != nil {
                        Button {
                            if state.carbs != 0,
                               (state.carbs - (((state.selection?.carbs ?? 0) as NSDecimalNumber) as Decimal) as Decimal) >= 0
                            {
                                state.carbs -= (((state.selection?.carbs ?? 0) as NSDecimalNumber) as Decimal)
                            } else { state.carbs = 0 }

                            if state.fat != 0,
                               (state.fat - (((state.selection?.fat ?? 0) as NSDecimalNumber) as Decimal) as Decimal) >= 0
                            {
                                state.fat -= (((state.selection?.fat ?? 0) as NSDecimalNumber) as Decimal)
                            } else { state.fat = 0 }

                            if state.protein != 0,
                               (
                                   state
                                       .protein - (((state.selection?.protein ?? 0) as NSDecimalNumber) as Decimal) as Decimal
                               ) >=
                               0
                            {
                                state.protein -= (((state.selection?.protein ?? 0) as NSDecimalNumber) as Decimal)
                            } else { state.protein = 0 }

                            // Handle note removal here
                            state.note = "" // Reset state.note

                            state.removePresetFromNewMeal()
                            if state.carbs == 0, state.fat == 0, state.protein == 0 { state.summation = [] }
                        }
                        label: {
                            Image(systemName: "minus")
                        }
                        .disabled(
                            state
                                .selection == nil ||
                                (
                                    !state.summation
                                        .contains(state.selection?.dish ?? "") && (state.selection?.dish ?? "") != ""
                                )
                        )
                        .tint(.blue)
                        .buttonStyle(.borderless)
                        Text("   numero    ")
                            .foregroundColor(.secondary)
                        Button {
                            state.carbs += ((state.selection?.carbs ?? 0) as NSDecimalNumber) as Decimal
                            state.fat += ((state.selection?.fat ?? 0) as NSDecimalNumber) as Decimal
                            state.protein += ((state.selection?.protein ?? 0) as NSDecimalNumber) as Decimal

                            // Handle note addition here
                            state.note = state.selection?.note ?? "" // Set state.note to the selected note

                            state.addPresetToNewMeal()
                        }
                        label: {
                            Image(systemName: "plus")
                        }
                        .disabled(state.selection == nil)
                        .tint(.blue)
                        .buttonStyle(.borderless)
                    }
                }
            }
        }

        @ViewBuilder private func proteinAndFat() -> some View {
            HStack {
                Text("Fat") // .fontWeight(.thin)
                Spacer()
                DecimalTextField(
                    "0",
                    value: $state.fat,
                    formatter: formatter,
                    autofocus: false,
                    cleanInput: true
                )
                Text("grams")
            }.foregroundColor(.brown)
            HStack {
                Text("Protein") // .fontWeight(.thin)
                Spacer()
                DecimalTextField(
                    "0",
                    value: $state.protein,
                    formatter: formatter,
                    autofocus: false,
                    cleanInput: true
                )
                Text("grams")
            }.foregroundColor(.brown)
            HStack {
                Text("Elenco").foregroundColor(.primary)
                TextField("...", text: $state.note).multilineTextAlignment(.trailing)
                if state.note != "", isFocused {
                    Button { isFocused = false } label: {
                        Image(systemName: "keyboard.chevron.compact.down") }
                        .controlSize(.mini)
                }
            }.focused($isFocused)
            // Time
            HStack {
                Text("orario")
                Spacer()
                if !pushed {
                    Button {
                        pushed = true
                    } label: { Text("ora") }.buttonStyle(.borderless).foregroundColor(.secondary)
                        .padding(.trailing, 5)
                } else {
                    Button { state.date = state.date.addingTimeInterval(-15.minutes.timeInterval) }
                    label: { Image(systemName: "mins") }.tint(.blue).buttonStyle(.borderless)
                    DatePicker(
                        "hour",
                        selection: $state.date,
                        displayedComponents: [.hourAndMinute]
                    ).controlSize(.mini)
                        .labelsHidden()
                    Button {
                        state.date = state.date.addingTimeInterval(15.minutes.timeInterval)
                    }
                    label: { Image(systemName: "plus") }.tint(.blue).buttonStyle(.borderless)
                }
            }
        }
    }
}

public extension Color {
    static func randomVibrantColor(randomOpacity: Bool = false) -> Color {
        let baseColor = Color(
            red: Double.random(in: 0.262745098 ... 0.7215686275),
            green: Double.random(in: 0.3411764706 ... 0.7333333333),
            blue: Double.random(in: 0.9137254902 ... 1),
            opacity: 1
        )

        let vibrantColor = baseColor.adjusted(by: 0.2)

        return randomOpacity ? vibrantColor.withRandomOpacity() : vibrantColor
    }
}

extension Color {
    func adjusted(by factor: Double) -> Color {
        guard let components = UIColor(self).rgbaComponents else {
            return self
        }

        return Color(
            red: min(components.red + CGFloat(factor), 1),
            green: min(components.green + CGFloat(factor), 1),
            blue: min(components.blue + CGFloat(factor), 1),
            opacity: components.alpha
        )
    }

    func withRandomOpacity() -> Color {
        Color(
            red: Double.random(in: 0.8 ... 1),
            green: Double.random(in: 0.8 ... 1),
            blue: Double.random(in: 0.8 ... 1),
            opacity: Double.random(in: 1 ... 1)
        )
    }
}

extension UIColor {
    var rgbaComponents: (red: CGFloat, green: CGFloat, blue: CGFloat, alpha: CGFloat)? {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0

        guard getRed(&red, green: &green, blue: &blue, alpha: &alpha) else {
            return nil
        }

        return (red, green, blue, alpha)
    }
}
