import SwiftUI

/// Shared form components styled to match the metadata edit sheet in `PlayerScreen`.

struct LabeledTextField: View {
    let label: String
    let placeholder: String
    @Binding var text: String

    var isSecure: Bool = false
    var textContentType: UITextContentType? = nil
    var keyboardType: UIKeyboardType = .default
    var autocapitalization: TextInputAutocapitalization = .never
    var disableAutocorrection: Bool = true

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .fontWeight(.semibold)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color("PrimaryText"))

            Group {
                if isSecure {
                    SecureField(placeholder, text: $text)
                } else {
                    TextField(placeholder, text: $text)
                }
            }
            .textContentType(textContentType)
            .textInputAutocapitalization(autocapitalization)
            .disableAutocorrection(disableAutocorrection)
            .keyboardType(keyboardType)
            .padding(12)
            .background(Color("Elevated"))
            .cornerRadius(24)
            .foregroundColor(.black)
        }
        .padding(.horizontal)
    }
}

struct PrimaryActionButton: View {
    let title: String
    var isLoading: Bool = false
    var isDisabled: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                if isLoading {
                    ProgressView()
                        .tint(Color("PrimaryText"))
                }

                Text(title)
                    .fontWeight(.semibold)
                    .foregroundColor(Color("SecondaryText"))
            }
            .frame(maxWidth: .infinity)
            .padding()
        }
        .buttonStyle(.glassProminent)
        .tint(Color("PrimaryBg"))
        .disabled(isDisabled || isLoading)
        .padding(.horizontal)
        .padding(.bottom)
    }
}




