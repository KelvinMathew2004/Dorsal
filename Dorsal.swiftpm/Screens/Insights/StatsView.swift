import SwiftUI
import Charts

struct StatsView: View {
    @ObservedObject var store: DreamStore
    
    var totalDreams: Int { store.dreams.count }
    var positiveDreams: Int { store.dreams.filter { ($0.extras?.sentimentScore ?? 50) > 60 }.count }
    var nightmareCount: Int { store.dreams.filter { $0.extras?.isNightmare ?? false }.count }
    var avgLucidity: Double {
        guard !store.dreams.isEmpty else { return 0 }
        let total = store.dreams.reduce(0) { $0 + ($1.extras?.lucidityScore ?? 0) }
        return Double(total) / Double(store.dreams.count)
    }
    var recentFatigue: [Dream] { store.dreams.prefix(7).reversed() }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Theme.gradientBackground.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        
                        if store.dreams.isEmpty {
                            ContentUnavailableView(
                                "No Data Available",
                                systemImage: "chart.bar.xaxis",
                                description: Text("Record some dreams to see your insights.")
                            )
                            .frame(height: 400)
                        } else {
                            // Weekly Overview
                            if let insights = store.weeklyInsight {
                                VStack(alignment: .leading, spacing: 16) {
                                    Label("Weekly Overview", systemImage: "sparkles.rectangle.stack").font(.headline).foregroundStyle(.white)
                                    MagicCard(title: "Period Summary", icon: "calendar", color: .indigo) {
                                        VStack(alignment: .leading, spacing: 12) {
                                            Text(insights.periodOverview ?? "Generating...").fixedSize(horizontal: false, vertical: true)
                                            Divider().background(.white.opacity(0.2))
                                            HStack {
                                                Label(insights.dominantTheme ?? "Theme", systemImage: "crown.fill").font(.caption.bold()).foregroundStyle(.yellow)
                                                Spacer()
                                                Text(insights.mentalHealthTrend ?? "Trend").font(.caption).foregroundStyle(.white.opacity(0.7))
                                            }
                                        }
                                    }
                                    MagicCard(title: "Advice", icon: "lightbulb.fill", color: .yellow) {
                                        Text(insights.strategicAdvice ?? "").italic()
                                    }
                                }
                                .padding(.horizontal)
                            } else if store.isGeneratingInsights {
                                ProgressView().tint(.white).padding().frame(maxWidth: .infinity)
                            } else if !store.dreams.isEmpty {
                                Button { Task { await store.refreshWeeklyInsights() } } label: {
                                    Label("Generate Insights", systemImage: "wand.and.stars").frame(maxWidth: .infinity).padding().background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12)).foregroundStyle(.white)
                                }.padding(.horizontal)
                            }
                            
                            // Mental Health Trends - ADDED PADDING
                            VStack(alignment: .leading, spacing: 12) {
                                Label("Mental Health Trends", systemImage: "brain.head.profile")
                                    .font(.headline).foregroundStyle(.white.opacity(0.8)).padding(.horizontal)
                                
                                ChartCard {
                                    Chart {
                                        ForEach(recentFatigue) { dream in
                                            LineMark(x: .value("Date", dream.date, unit: .day), y: .value("Anxiety", dream.extras?.anxietyLevel ?? 0)).foregroundStyle(.pink).interpolationMethod(.catmullRom)
                                            LineMark(x: .value("Date", dream.date, unit: .day), y: .value("Sentiment", dream.extras?.sentimentScore ?? 50)).foregroundStyle(.green).interpolationMethod(.catmullRom)
                                        }
                                    }
                                    .chartYScale(domain: 0...100)
                                    .frame(height: 200)
                                } caption: {
                                    HStack(spacing: 16) {
                                        Label("Anxiety", systemImage: "circle.fill").foregroundStyle(.pink)
                                        Label("Sentiment", systemImage: "circle.fill").foregroundStyle(.green)
                                    }
                                    .font(.caption)
                                }
                                .padding(.horizontal)
                            }
                            
                            // Key Stats
                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                                StatCard(title: "Entries", value: "\(totalDreams)", icon: "book.fill", color: .blue)
                                StatCard(title: "Nightmares", value: "\(nightmareCount)", icon: "exclamationmark.triangle.fill", color: .purple)
                                StatCard(title: "Lucidity", value: "\(Int(avgLucidity))%", icon: "eye.fill", color: .cyan)
                                StatCard(title: "Positive", value: "\(positiveDreams)", icon: "hand.thumbsup.fill", color: .green)
                            }
                            .padding(.horizontal)
                            
                            // Sleep Fatigue - ADDED PADDING
                            VStack(alignment: .leading, spacing: 12) {
                                Label("Sleep Fatigue", systemImage: "waveform.path.ecg")
                                    .font(.headline).foregroundStyle(.white.opacity(0.8)).padding(.horizontal)
                                
                                ChartCard {
                                    Chart {
                                        ForEach(recentFatigue) { dream in
                                            BarMark(x: .value("Date", dream.date, unit: .day), y: .value("Fatigue", dream.core?.voiceFatigue ?? 0))
                                                .foregroundStyle(gradient(for: dream.core?.voiceFatigue ?? 0))
                                        }
                                    }
                                    .frame(height: 180)
                                } caption: {
                                    Text("Higher bars indicate higher vocal fatigue.").font(.caption).foregroundStyle(.secondary)
                                }
                                .padding(.horizontal)
                            }
                            
                            // Memory Health - ADDED PADDING
                            VStack(alignment: .leading, spacing: 12) {
                                Label("Memory Recall", systemImage: "memorychip")
                                    .font(.headline).foregroundStyle(.white.opacity(0.8)).padding(.horizontal)
                                
                                HStack(spacing: 16) {
                                    RingView(percentage: Double(avgMetric { $0.extras?.vividnessScore ?? 0 }), title: "Vividness", color: .orange)
                                    RingView(percentage: Double(avgMetric { $0.extras?.coherenceScore ?? 0 }), title: "Coherence", color: .teal)
                                }
                                .padding(.horizontal)
                            }
                        }
                        
                        Spacer(minLength: 50)
                    }
                    .padding(.top)
                }
            }
            // Use native navigation title now
            .navigationTitle("Insights")
            .navigationBarTitleDisplayMode(.large)
            .onAppear {
                if store.weeklyInsight == nil && !store.dreams.isEmpty {
                    Task { await store.refreshWeeklyInsights() }
                }
            }
        }
    }
    
    // Helpers (Same as before)
    func avgMetric(_ keyPath: (Dream) -> Int) -> Int {
        guard !store.dreams.isEmpty else { return 0 }
        let total = store.dreams.reduce(0) { $0 + keyPath($1) }
        return total / store.dreams.count
    }
    
    func gradient(for score: Int) -> LinearGradient {
        let color = score > 70 ? Color.red : (score > 40 ? Color.yellow : Color.blue)
        return LinearGradient(colors: [color.opacity(0.8), color.opacity(0.3)], startPoint: .top, endPoint: .bottom)
    }
}
