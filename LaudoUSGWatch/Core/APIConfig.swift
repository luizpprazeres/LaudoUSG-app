import Foundation

enum APIConfig {
    static let apiBaseURL = URL(string: "https://laudousgmobile.vercel.app")!
    static let supabaseURL = URL(string: "https://yldtkqrsbgcnwlydrrot.supabase.co")!
    static let supabaseAnonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InlsZHRrcXJzYmdjbndseWRycm90Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzg3ODk2NjgsImV4cCI6MjA5NDM2NTY2OH0.lvEJIwyHH-fMqLsDiad_8YlETNTfTFeWdgenRsPDTBY"
    static let defaultWritingStyleId = "11111111-1111-4111-8111-111111111111"
    static let maxRecordingSeconds: TimeInterval = 60
}
