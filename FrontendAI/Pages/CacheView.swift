//
//  CacheView.swift
//  FrontendAI
//
//  Created by macbook on 29.04.2026.
//

import SwiftUI
import SwiftData
import Charts

struct CacheView: View {
    var body: some View {
        Text("CacheView")
        
        List {
            Section ("Cache info"){
                SectorChartExample()
                    .frame(height: 300)
            }
            Section ("Cache per chat") {
                Button {
                    
                } label : {
                    Text("Clear all cache")
                }
                ForEach (0..<7) { _ in
                    HStack {
                        Image(systemName: "person.fill")
                        Text("Chat 1")
                            .bold(true)
                        Spacer()
                        Text("16 kb")
                    }
                }
            }
        }
    }
}

struct Product: Identifiable {
    let id = UUID()
    let title: String
    let revenue: Double
}

struct SectorChartExample: View {
    @State private var products: [Product] = [
        .init(title: "Yoga assistant", revenue: 0.4),
        .init(title: "Helpful assistant", revenue: 0.3),
        .init(title: "Character recognition assistant 2", revenue: 0.2),
        .init(title: "Others", revenue: 0.1)
    ]
    
    var body: some View {
        Chart(products) { product in
            SectorMark(
                angle: .value(
                    Text(verbatim: product.title),
                    product.revenue
                ),
                innerRadius: .ratio(0.6)
            )
            .foregroundStyle(
                by: .value(
                    Text(verbatim: product.title),
                    product.title
                )
            )
        }
    }
}

#Preview {
    CacheView()
}
