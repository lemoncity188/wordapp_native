import SwiftUI

struct RootView: View {
    @EnvironmentObject var model: WordModel
    var body: some View {
        Group {
            if model.token.isEmpty { AuthView() }
            else {
                TabView(selection: $model.selectedTab) {
                    StudyView().badge(max(0, model.queue.count - model.cursor)).tabItem { Label("单词", systemImage: "book") }.tag(0)
                    LibraryView().tabItem { Label("词库", systemImage: "books.vertical") }.tag(1)
                    AccountView().tabItem { Label("我的", systemImage: "person") }.tag(2)
                }
                .toolbar(.hidden, for: .tabBar)
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    HStack(spacing: 10) {
                        tabButton("单词", index: 0)
                        tabButton("词库", index: 1)
                        tabButton("我的", index: 2)
                    }.padding(12).background(Color.white)
                }
            }
        }
        .tint(Color(red: 0.15, green: 0.65, blue: 0.60))
        .overlay { if model.busy { ProgressView().padding(24).background(.regularMaterial).cornerRadius(12) } }
        .disabled(model.busy)
        .alert("提示", isPresented: Binding(get: { !model.message.isEmpty }, set: { if !$0 { model.message = "" } })) { Button("确定") { model.message = "" } } message: { Text(model.message) }
    }
    func tabButton(_ title: String, index: Int) -> some View {
        let selected = model.selectedTab == index
        return Button { model.selectedTab = index } label: {
            HStack(spacing: 5) {
                Text(title)
                if index == 0 && model.queue.count > model.cursor { Text("· \(model.queue.count - model.cursor)").font(.caption) }
            }.font(.system(size: 15, weight: .medium)).frame(maxWidth: .infinity).frame(height: 44)
                .foregroundColor(selected ? .white : Color(red: 0.33, green: 0.45, blue: 0.42))
                .background(selected ? Color(red: 0.157, green: 0.525, blue: 0.431) : Color(red: 0.94, green: 0.965, blue: 0.95)).cornerRadius(14)
        }.buttonStyle(.plain).accessibilityAddTraits(selected ? .isSelected : [])
    }
}
struct AuthView: View {
    @EnvironmentObject var model: WordModel
    @State private var mode = 0
    @State private var mobile = ""
    @State private var password = ""
    @State private var repeatPassword = ""
    @State private var name = ""
    @State private var code = ""
    @State private var privacy = false
    @State private var agreed = false
    @State private var countdown = 0
    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                ScrollView {
                    VStack(spacing: 16) {
                        AsyncImage(url: URL(string: "https://lemoncity.oss-cn-shanghai.aliyuncs.com/logo/firefox_word.png")) { image in image.resizable().scaledToFit() } placeholder: { Color.clear }.frame(width: 66, height: 66).padding(.bottom, 24)
                        field { TextField("请输入手机号", text: $mobile).keyboardType(.phonePad).textContentType(.username) }
                        if mode == 1 { field { TextField("请输入用户名", text: $name) } }
                        field { SecureField("请输入密码", text: $password) }
                        if mode != 0 {
                            field { SecureField("确认密码", text: $repeatPassword) }
                            HStack {
                                field { TextField("验证码", text: $code).keyboardType(.numberPad) }
                                Button(countdown > 0 ? "\(countdown)秒后重试" : "发送验证码") {
                                    model.run {
                                        guard mobile.range(of: "^[0-9]{11}$", options: .regularExpression) != nil else { throw AppFailure(message: "请输入11位手机号") }
                                        _ = try await model.post("user/sendCode", ["mobile": try encrypt(mobile)])
                                        countdown = 60
                                    }
                                }.disabled(countdown > 0)
                            }
                        }
                        Button(mode == 0 ? "登陆" : mode == 1 ? "注册" : "修改密码") {
                            model.run {
                                guard mode == 0 || password == repeatPassword else { throw AppFailure(message: "两次密码输入不一致") }
                                guard mode != 1 || agreed else { throw AppFailure(message: "请先阅读并同意隐私政策") }
                                try await model.authenticate(mode: mode, mobile: mobile, password: password, name: name, code: code)
                                if mode != 0 { mode = 0; password = ""; repeatPassword = ""; code = "" }
                            }
                        }.frame(maxWidth: .infinity).frame(height: 48).foregroundColor(.white).background(Color(red: 0.15, green: 0.65, blue: 0.60)).cornerRadius(4).padding(.top, 16)
                        if mode == 0 {
                            Button("立即注册") { privacy = true }.padding(.top, 14)
                            Button("忘记密码") { mode = 2 }.padding(.top, 14)
                        } else { Button("已有账号去登陆") { mode = 0 } }
                    }.font(.system(size: 16)).padding(.horizontal, 40).padding(.vertical, 32).frame(minHeight: geometry.size.height)
                }.background(Color.white)
            }
            .sheet(isPresented: $privacy) {
                NavigationStack {
                    VStack {
                        PrivacyView()
                        HStack {
                            Button("拒绝") { privacy = false }
                            Spacer()
                            Button("同意") { agreed = true; mode = 1; privacy = false }
                        }.padding(24)
                    }
                }
            }
            .task(id: countdown) {
                guard countdown > 0 else { return }
                do { try await Task.sleep(nanoseconds: 1_000_000_000); countdown -= 1 } catch { }
            }
        }
    }
    func field<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content().textInputAutocapitalization(.never).autocorrectionDisabled().padding(.horizontal, 16).frame(height: 48).background(Color(white: 0.975)).cornerRadius(6).overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.black.opacity(0.1)))
    }
}
struct StudyView: View {
    @EnvironmentObject var model: WordModel
    @State private var translation = ""
    @State private var editing = false
    @State private var dictionaries = false
    var body: some View {
        NavigationStack {
            VStack {
                if model.busy { Spacer(); ProgressView(); Spacer() }
                else if !model.studyLoaded { Spacer(); Button("加载学习记录") { model.run { try await model.loadStudy() } }; Spacer() }
                else if let item = model.current {
                    Text(item["word"] as? String ?? "").font(.system(size: 36, weight: .bold)).foregroundColor(Color(red: 0.157, green: 0.525, blue: 0.431)).padding(.top, 30)
                    HStack {
                        Text("美[" + ((item["vocabulary"] as? JSON)?["usPhonetic"] as? String ?? "") + "]").foregroundColor(.secondary)
                        Button { model.run { try await model.speak() } } label: { Image(systemName: "speaker.wave.2").font(.system(size: 20)).foregroundColor(Color(red: 0.157, green: 0.525, blue: 0.431)).frame(width: 36, height: 36).background(Color(red: 0.929, green: 0.969, blue: 0.949)).clipShape(Circle()) }.accessibilityLabel("播放单词发音")
                    }
                    ScrollView {
                        if model.revealed {
                            VStack(alignment: .leading, spacing: 18) {
                                if let custom = item["translation"] as? String, !custom.isEmpty { section("个人", custom) }
                                section("官方", model.officialDefinition(item))
                                section("例句", ((item["vocabulary"] as? JSON)?["sentence"] as? String ?? "").replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression))
                                section("短语", model.phrases(item))
                                HStack {
                                    Button { translation = item["translation"] as? String ?? ""; editing = true } label: { Label("编辑释义", systemImage: "square.and.pencil") }
                                    Spacer()
                                    Button { dictionaries = true } label: { Label("查词典", systemImage: "link") }
                                }
                            }.padding(24)
                        } else {
                            Text("点击查看释义").foregroundColor(.secondary).frame(maxWidth: .infinity).frame(height: 300).background(Color.white).contentShape(Rectangle()).onTapGesture { model.revealed = true; model.run { try await model.speak() } }
                        }
                    }
                    HStack(spacing: 20) {
                        gradeButton("认识", .green, 1)
                        gradeButton("模糊", .orange, -1)
                        gradeButton("忘记", .red, nil)
                    }.padding(24)
                } else {
                    Spacer()
                    Image("MissionComplete").resizable().scaledToFit().frame(width: 180, height: 180)
                    Text("任务完成").font(.title2).foregroundColor(.teal)
                    Spacer()
                }
            }.toolbar(.hidden, for: .navigationBar)
            .task { model.run { try await model.loadStudy() } }
            .sheet(isPresented: $editing) {
                NavigationStack {
                    TextEditor(text: $translation).padding().navigationTitle("编辑释义").toolbar {
                        ToolbarItem(placement: .cancellationAction) { Button("取消") { editing = false } }
                        ToolbarItem(placement: .confirmationAction) { Button("确定") { model.run { try await model.editTranslation(translation); editing = false } } }
                    }
                }.presentationDetents([.medium])
            }
            .sheet(isPresented: $dictionaries) {
                HStack(spacing: 40) {
                    dictionary("金山", "https://m.iciba.com/")
                    dictionary("欧路", "https://dict.eudic.net/mdicts/en/")
                    dictionary("有道", "https://m.youdao.com/dict?le=eng&q=")
                }.presentationDetents([.height(150)])
            }
        }
    }
    @ViewBuilder func section(_ title: String, _ text: String) -> some View {
        if !text.isEmpty { Text(title).font(.caption).foregroundColor(.teal); Text(text).frame(maxWidth: .infinity, alignment: .leading) }
    }
    func gradeButton(_ title: String, _ color: Color, _ delta: Int?) -> some View {
        Button(title) { model.run { try await model.grade(delta) } }.frame(maxWidth: .infinity).padding(.vertical, 12).foregroundColor(color).background(color.opacity(0.08)).cornerRadius(4)
    }
    @ViewBuilder func dictionary(_ title: String, _ base: String) -> some View {
        if let word = (model.current?["word"] as? String)?.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed), let url = URL(string: base + word) { Link(title, destination: url) }
    }
}
struct LibraryView: View {
    @EnvironmentObject var model: WordModel
    var body: some View {
        NavigationStack {
            List {
                ForEach(Array(model.libraries.enumerated()), id: \.offset) { _, group in
                    Section {
                    DisclosureGroup {
                        ForEach(Array((group["subLibrary"] as? [JSON] ?? []).enumerated()), id: \.offset) { _, book in
                            NavigationLink { WordListView(book: book) } label: { Text(book["name"] as? String ?? "词书").font(.system(size: 16)).foregroundColor(Color(red: 0.24, green: 0.34, blue: 0.31)).padding(.vertical, 8) }
                        }
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "books.vertical").font(.title3).foregroundColor(.teal).frame(width: 42, height: 42).background(Color.teal.opacity(0.08)).cornerRadius(12)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(group["desc"] as? String ?? "词库").font(.system(size: 17, weight: .medium)).foregroundColor(.primary)
                                Text("\((group["subLibrary"] as? [JSON] ?? []).count) 本词书").font(.caption).foregroundColor(.secondary)
                            }
                        }.padding(.vertical, 8)
                    }
                    }
                }
                Section { Text("自定义词书网址：http://47.97.107.100:8055").font(.caption2).foregroundColor(.secondary).frame(maxWidth: .infinity).listRowBackground(Color.clear) }
            }.listStyle(.insetGrouped).scrollContentBackground(.hidden).background(Color(red: 0.96, green: 0.975, blue: 0.97)).navigationTitle("词库").toolbar { Button { load() } label: { Image(systemName: "arrow.clockwise") } }.task { load() }
        }
    }
    func load() { model.run { model.libraries = try await model.post("library/pageList") as? [JSON] ?? [] } }
}
struct WordListView: View {
    @EnvironmentObject var model: WordModel
    @Environment(\.dismiss) private var dismiss
    let book: JSON
    @State private var items: [JSON] = []
    @State private var selected: Set<Int> = []
    var body: some View {
        List {
            Button("全选") { selected = Set(items.indices) }
            ForEach(items.indices, id: \.self) { index in
                Button { if selected.contains(index) { selected.remove(index) } else { selected.insert(index) } } label: {
                    HStack { Text(items[index]["word"] as? String ?? ""); Spacer(); if selected.contains(index) { Image(systemName: "checkmark.circle.fill") } }
                }
            }
        }.navigationTitle("单词列表")
            .toolbar { Button("保存") { model.run {
                let result = try await model.post("library/saveCheckedWord", selected.sorted().map { index -> JSON in var item = items[index]; item["checked"] = true; return item })
                if let code = result as? Int, code < 0 { throw AppFailure(message: code == -1 ? "已超过会员单词额度" : "已超过最大单词上限") }
                try await model.loadStudy()
                dismiss()
                model.selectedTab = 0
            } }.disabled(selected.isEmpty) }
            .task { model.run { items = try await model.post("library/wordList", ["id": book["id"] ?? 0, "parentCode": book["parentCode"] ?? ""]) as? [JSON] ?? []; selected = Set(items.indices.filter { items[$0]["checked"] as? Bool == true }) } }
    }
}
struct AccountView: View {
    @EnvironmentObject var model: WordModel
    @State private var feedback = ""
    @State private var deleting = false
    @State private var feedbackOpen = false
    @State private var settingVIP = false
    @State private var vipUsername = ""
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: 24) {
                        AsyncImage(url: URL(string: model.profile["avatar"] as? String ?? "https://lemoncity.oss-cn-shanghai.aliyuncs.com/avatar/avater01.png")) { image in image.resizable().scaledToFill() } placeholder: { Image(systemName: "person.circle") }.frame(width: 80, height: 80).clipShape(Circle())
                        VStack(alignment: .leading, spacing: 12) {
                            Text(model.profile["name"] as? String ?? model.profile["username"] as? String ?? "").font(.system(size: 22, weight: .bold))
                            Text((model.profile["vip"] as? Int ?? 0) == 0 ? "普通用户" : "VIP").font(.caption).foregroundColor(.teal).padding(.horizontal, 10).padding(.vertical, 4).background(Color.teal.opacity(0.08)).clipShape(Capsule())
                        }
                    }.padding(.vertical, 20)
                }.listRowBackground(Color(red: 0.92, green: 0.96, blue: 0.94))
                Section {
                Button { feedbackOpen = true } label: { settingsLabel("用户意见", "square.and.pencil") }
                if (model.profile["vip"] as? Int) == 8 { Button("设置vip") { settingVIP = true } }
                NavigationLink { MembershipView() } label: { settingsLabel("会员说明", "star") }
                NavigationLink { PrivacyView() } label: { settingsLabel("隐私政策", "checkmark.shield") }
                }
                Section {
                    Button { model.run { try await model.logout() } } label: { settingsLabel("登出", "rectangle.portrait.and.arrow.right") }
                    Button(role: .destructive) { deleting = true } label: { settingsLabel("注销用户", "person.crop.circle.badge.minus", danger: true) }
                }
                Section { Text("官网：www.redfox18.com").font(.caption).foregroundColor(.secondary).frame(maxWidth: .infinity).listRowBackground(Color.clear) }
            }.scrollContentBackground(.hidden).background(Color(red: 0.96, green: 0.975, blue: 0.97)).navigationTitle("我的").task { model.run { model.profile = try await model.post("user/info") as? JSON ?? [:] } }
                .sheet(isPresented: $feedbackOpen) {
                    NavigationStack {
                        TextEditor(text: $feedback).padding().navigationTitle("您的宝贵建议").toolbar {
                            ToolbarItem(placement: .cancellationAction) { Button("取消") { feedbackOpen = false } }
                            ToolbarItem(placement: .confirmationAction) { Button("确定") { model.run { _ = try await model.post("suggest/insert", ["userId": model.profile["userId"] ?? 0, "content": feedback]); feedback = ""; feedbackOpen = false; model.message = "感谢反馈" } }.disabled(feedback.isEmpty) }
                        }
                    }
                }
                .alert("设置vip", isPresented: $settingVIP) {
                    TextField("请输入用户名", text: $vipUsername)
                    Button("取消", role: .cancel) { }
                    Button("确定") { model.run { _ = try await model.post("user/setting/vip", ["username": vipUsername]); model.message = vipUsername + "设置vip成功" } }
                }
                .confirmationDialog("注销将删除账号，是否继续？", isPresented: $deleting, titleVisibility: .visible) { Button("确认注销", role: .destructive) { model.run { _ = try await model.post("user/removal", ["id": model.profile["userId"] ?? 0]); try TokenStore.save(""); model.token = ""; model.clearUser() } } }
        }
    }
}
extension AccountView {
    func settingsLabel(_ title: String, _ icon: String, danger: Bool = false) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon).font(.system(size: 17)).foregroundColor(danger ? .red : .teal).frame(width: 36, height: 36).background((danger ? Color.red : Color.teal).opacity(0.07)).cornerRadius(10)
            Text(title).font(.system(size: 16)).foregroundColor(danger ? .red : .primary)
            Spacer()
        }.padding(.vertical, 4)
    }
}
struct PrivacyView: View {
    var body: some View { ScrollView { Text(privacyText).padding() }.navigationTitle("隐私政策") }
}

struct MembershipView: View {
    var body: some View {
        ScrollView { VStack(spacing: 24) {
            Text("支付宝二维码").font(.title)
            Image("VIPCode").resizable().scaledToFit().frame(maxWidth: 280)
            Text("请在支付备注中填写用户名，一个工作日左右开通。如未开通，请联系QQ客服：1760612965")
            Text("单词年度VIP ¥88\n听力与单词年度双VIP ¥158")
            Text("以上内容沿用原项目会员说明。").foregroundColor(.secondary)
        }.padding() }.navigationTitle("会员说明")
    }
}
