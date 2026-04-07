import SwiftUI

struct OptionalDatePickerRow: View {
    let title: String
    @Binding var selection: Date?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Toggle(isOn: isEnabledBinding) {
                Text(title)
                    .font(.subheadline.weight(.medium))
            }
            .toggleStyle(.switch)

            if selection != nil {
                DatePicker(
                    title,
                    selection: dateBinding,
                    displayedComponents: .date
                )
                .labelsHidden()
            }
        }
    }

    private var isEnabledBinding: Binding<Bool> {
        Binding(
            get: { selection != nil },
            set: { isEnabled in
                selection = isEnabled ? (selection ?? .now) : nil
            }
        )
    }

    private var dateBinding: Binding<Date> {
        Binding(
            get: { selection ?? .now },
            set: { selection = $0 }
        )
    }
}
