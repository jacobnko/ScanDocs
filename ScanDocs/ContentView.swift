// 프로젝트 초기 셋업 확인용 임시 루트 뷰 (Step 1에서 실제 화면으로 교체 예정)
import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "doc.viewfinder")
                .font(.system(size: 48))
                .foregroundStyle(.tint)
            Text("ScanDocs")
                .font(.title2.bold())
        }
        .frame(width: 380)
    }
}

#Preview {
    ContentView()
        .frame(width: 400, height: 600)
        .preferredColorScheme(.light)
}
