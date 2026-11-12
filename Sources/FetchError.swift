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
        case .notSignedIn(let what): return "\(what) 로그인 정보 없음"
        case .unauthorized: return "토큰 만료됨"
        case .http(let code): return "서버 오류 \(code)"
        case .toolMissing(let name): return "\(name) 설치되지 않음"
        case .toolFailed(let detail): return detail
        case .timedOut: return "응답 시간 초과"
        }
    }
}
