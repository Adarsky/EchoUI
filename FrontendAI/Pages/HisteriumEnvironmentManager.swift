//
//  HisteriumEnvironmentManager.swift
//  FrontendAI
//
//  Created by macbook on 07.04.2026.
//

import SwiftUI

struct HisteriumEnvironmentManager: View {
    var body: some View {
        VStack {
            Text("Hysterium Environment Manager")
                .bold(true)
                .font(.largeTitle)
            HStack{
                Text("Be aware! Currently in beta stage.")
                    .font(.caption)
            }
        }
        .padding(20)
        .navigationBarTitle("Histerium")
        
        List {
            Section(header: Text("Base settings"), footer: Text("* We do NOT recommend using this feature casually.")) {
                Toggle("Hysterical connection", isOn: .constant(true))
            }
            Section(header: Text("VLESS proxies: <howmany?>"), footer: Text("* Use only those providers that you fully trust and are convinced of their transparency and security. Any provider can see your connections, and an unverified provider can leak your data or transfer it to third parties.")) {
                HStack {
                    Text("fi-hel-002")
                    Spacer()
                    Text("REALITY")
                        .font(.caption)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.green.opacity(0.4))
                        )
                    Text("XHTTP")
                        .font(.caption)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.yellow.opacity(0.4))
                        )
                    Spacer()
                    Circle()
                        .fill(Color.green)
                        .frame(width: 10, height: 10)
                        .padding(.horizontal, 30)
                }
                HStack {
                    Text("fi-hel-002")
                    Spacer()
                    Text("REALITY")
                        .font(.caption)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.green.opacity(0.4))
                        )
                    Text("gPRC")
                        .font(.caption)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.yellow.opacity(0.4))
                        )
                    Spacer()
                    Circle()
                        .fill(Color.green)
                        .frame(width: 10, height: 10)
                        .padding(.horizontal, 30)
                }
                HStack {
                    Text("fi-hel-002")
                    Spacer()
                    Text("none")
                        .font(.caption)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.red.opacity(0.4))
                        )
                    Text("TCP")
                        .font(.caption)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.yellow.opacity(0.4))
                        )
                    Spacer()
                    Circle()
                        .fill(Color.green)
                        .frame(width: 10, height: 10)
                        .padding(.horizontal, 30)
                }
                HStack {
                    Image(systemName: "plus")
                    Text("Add new proxy")
                }
            }
            Section(header: Text("Hysteria connection configuration"), footer: Text("*")) {
                Toggle("Randomise client name", isOn: .constant(true))
                NavigationLink(destination: ClientNamesRandomisingManagerView()) {
                    HStack {
                        Image(systemName: "tag")
                        Text("Client name settings")
                    }
                }
            }
        }
    }
}

#Preview {
    HisteriumEnvironmentManager()
}
