import SwiftUI

struct LibraryView: View {
    @Environment(\.forgeTheme) private var T
    @EnvironmentObject private var certStore: CertificateStore
    @AppStorage("appLanguage") private var appLanguage: String = "ar"
    
    @State private var showCertificatesSheet = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // بطاقة تنبيه الشهادات
                    Button(action: { showCertificatesSheet = true }) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(appLanguage == "ar" ? "إدارة الشهادات" : "Manage Certificates")
                                    .font(T.sans(14, .bold))
                                    .foregroundColor(T.ink)
                                
                                let certNoticeText = (appLanguage == "ar") ? "أضف شهادة p12 وملف mobileprovision" : "Add .p12 & .mobileprovision"
                                Text(certNoticeText)
                                    .font(T.sans(12, .regular))
                                    .foregroundColor(T.ink3)
                            }
                            Spacer()
                            Image(systemName: "chevron.left")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(T.ink3)
                        }
                        .padding(16)
                        .fGlass(cornerRadius: 12)
                    }

                    // قائمة التطبيقات أو المكونات الأخرى داخل المكتبة
                    VStack(alignment: .leading, spacing: 12) {
                        Text(appLanguage == "ar" ? "التطبيقات الموقعة" : "Signed Apps")
                            .font(T.sans(16, .bold))
                            .foregroundColor(T.ink)
                            .padding(.horizontal, 4)

                        VStack(spacing: 12) {
                            Image(systemName: "doc.badge.gearshape")
                                .font(.system(size: 40))
                                .foregroundColor(T.ink3)
                            
                            Text(appLanguage == "ar" ? "لا توجد تطبيقات موقعة حالياً" : "No signed apps yet")
                                .font(T.sans(14, .regular))
                                .foregroundColor(T.ink2)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(32)
                        .fGlass(cornerRadius: 12)
                    }
                }
                .padding(16)
            }
            .background { ForgeBackdrop() }
            .navigationTitle(appLanguage == "ar" ? "المكتبة" : "Library")
            .sheet(isPresented: $showCertificatesSheet) {
                CertificatesSheet(certStore: certStore)
            }
        }
    }
}
