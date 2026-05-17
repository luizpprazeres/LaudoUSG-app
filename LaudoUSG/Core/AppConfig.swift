import Foundation

enum AppConfig {
    static let apiBaseURL = URL(string: "https://laudousgmobile.vercel.app")!
    static let supabaseURL = URL(string: "https://yldtkqrsbgcnwlydrrot.supabase.co")!
    static let supabaseAnonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InlsZHRrcXJzYmdjbndseWRycm90Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzg3ODk2NjgsImV4cCI6MjA5NDM2NTY2OH0.lvEJIwyHH-fMqLsDiad_8YlETNTfTFeWdgenRsPDTBY"

    static let promptVersion = "v1"
    static let contractVersion = "v1"
    static let findingsSchemaVersion = "v1"

    static let speechLocale = "pt-BR"
    static let maxAudioSeconds = 600
}
