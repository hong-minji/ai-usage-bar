import Foundation

enum FetchError: LocalizedError {
    case notSignedIn(String)
    case unauthorized
    case http(Int)
    case toolMissing(String)
    case toolFailed(String)
    case timedOut

    var errorDescription: String? {
        switch self {
        case .notSignedIn(let what): return L("\(what) 로그인 정보 없음", "No \(what) login found")
        case .unauthorized: return L("토큰 만료됨", "Token expired")
        case .http(let code): return L("서버 오류 \(code)", "Server error \(code)")
        case .toolMissing(let name): return L("\(name) 설치되지 않음", "\(name) is not installed")
        case .toolFailed(let detail): return detail
        case .timedOut: return L("응답 시간 초과", "Timed out")
        }
    }
}
