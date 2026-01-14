import SwiftUI
import Contacts

struct ContactDetailView: View {
    let contact: CNContact
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            List {
                // Header
                Section {
                    HStack(spacing: 16) {
                        if let data = contact.imageData, let uiImage = UIImage(data: data) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 60, height: 60)
                                .clipShape(Circle())
                        } else {
                            Image(systemName: "person.circle.fill")
                                .resizable()
                                .frame(width: 60, height: 60)
                                .foregroundStyle(.gray)
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("\(contact.givenName) \(contact.familyName)")
                                .font(.title3.bold())
                            
                            if !contact.jobTitle.isEmpty {
                                Text(contact.jobTitle)
                                    .font(.subheadline)
                                    .foregroundStyle(Theme.secondary)
                            }
                            
                            if !contact.organizationName.isEmpty {
                                Text(contact.organizationName)
                                    .font(.caption)
                                    .foregroundStyle(Theme.secondary)
                            }
                        }
                    }
                    .padding(.vertical, 8)
                }
                
                // Phone Numbers
                if contact.isKeyAvailable(CNContactPhoneNumbersKey) && !contact.phoneNumbers.isEmpty {
                    Section("Phone") {
                        ForEach(contact.phoneNumbers, id: \.identifier) { phone in
                            LabeledContent {
                                Text(phone.value.stringValue)
                                    .textSelection(.enabled)
                            } label: {
                                Text(convertLabel(phone.label ?? "mobile"))
                            }
                        }
                    }
                }
                
                // Emails
                if contact.isKeyAvailable(CNContactEmailAddressesKey) && !contact.emailAddresses.isEmpty {
                    Section("Email") {
                        ForEach(contact.emailAddresses, id: \.identifier) { email in
                            LabeledContent {
                                Text(email.value as String)
                                    .textSelection(.enabled)
                            } label: {
                                Text(convertLabel(email.label ?? "email"))
                            }
                        }
                    }
                }
                
                // Birthday
                if contact.isKeyAvailable(CNContactBirthdayKey), let birthday = contact.birthday, let date = birthday.date {
                    Section("Birthday") {
                        LabeledContent("Date") {
                            Text(date.formatted(date: .long, time: .omitted))
                        }
                    }
                }
                
                // Address
                if contact.isKeyAvailable(CNContactPostalAddressesKey) && !contact.postalAddresses.isEmpty {
                    Section("Address") {
                        ForEach(contact.postalAddresses, id: \.identifier) { address in
                            VStack(alignment: .leading) {
                                Text(convertLabel(address.label ?? "home"))
                                    .font(.caption)
                                    .foregroundStyle(Theme.secondary)
                                Text(formatAddress(address.value))
                            }
                        }
                    }
                }
                
                // Social Profiles
                if contact.isKeyAvailable(CNContactSocialProfilesKey) && !contact.socialProfiles.isEmpty {
                    Section("Social") {
                        ForEach(contact.socialProfiles, id: \.identifier) { profile in
                            LabeledContent {
                                Text(profile.value.username)
                                    .textSelection(.enabled)
                            } label: {
                                Text(profile.value.service.capitalized)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Contact Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(role: .close) { dismiss() }
                }
            }
        }
    }
    
    func convertLabel(_ label: String) -> String {
        return CNLabeledValue<NSString>.localizedString(forLabel: label)
    }
    
    func formatAddress(_ address: CNPostalAddress) -> String {
        return [address.street, address.city, address.state, address.postalCode, address.country]
            .filter { !$0.isEmpty }
            .joined(separator: "\n")
    }
}
