import { common } from '@kit.AbilityKit';
import { media } from '@kit.MediaKit';
import { Api, AuthBody, MobileBody, BookBody, SaveBody, SoundBody, FeedbackBody, RemoveBody,
  User, Word, LibraryGroup, Book, RecordData, due, officialDefinition, phrases, VipBody, encrypt } from '../model/Api';
import { privacyText } from '../model/Privacy';

@Entry
@Component
struct Index {
  private api: Api = new Api();
  private player?: media.AVPlayer;
  @State ready: boolean = false;
  @State loggedIn: boolean = false;
  @State studyLoaded: boolean = false;
  @State busy: boolean = false;
  @State notice: string = '';
  @State tab: number = 0;
  @State authMode: number = 0;
  @State mobile: string = '';
  @State password: string = '';
  @State repeatPassword: string = '';
  @State privacyRegistration: boolean = false;
  @State editing: boolean = false;
  @State dictionaries: boolean = false;
  @State feedbackOpen: boolean = false;
  @State vipOpen: boolean = false;
  @State vipUsername: string = '';
  @State expanded: number[] = [];
  @State countdown: number = 0;
  private countdownTimer: number = -1;
  @State username: string = '';
  @State code: string = '';
  @State agreed: boolean = false;
  @State server: string = 'http://47.97.107.100:8088/api/';
  @State groups: LibraryGroup[] = [];
  @State words: Word[] = [];
  @State selected: number[] = [];
  @State bookTitle: string = '';
  @State records: Word[] = [];
  @State queue: Word[] = [];
  @State cursor: number = 0;
  @State revealed: boolean = false;
  @State translation: string = '';
  @State user: User = { userId: 0, username: '', vip: 0 };
  @State feedback: string = '';
  @State showingPrivacy: boolean = false;
  @State showingVIP: boolean = false;

  aboutToAppear(): void {
    this.execute(async () => {
      await this.api.init(getContext(this) as common.UIAbilityContext);
      this.server = this.api.baseURL; this.ready = true; this.loggedIn = this.api.token.length > 0;
      if (this.api.token) { await this.loadStudy(); }
    });
  }
  aboutToDisappear(): void { this.player?.release(); clearInterval(this.countdownTimer); }
  async execute(work: () => Promise<void>): Promise<void> {
    if (this.busy) { return; }
    this.busy = true; this.notice = '';
    try { await work(); } catch (error) { this.notice = (error as Error).message || '操作失败，请重试'; }
    finally { this.loggedIn = this.api.token.length > 0; this.busy = false; }
  }
  async authenticate(): Promise<void> {
    if (!/^\d{11}$/.test(this.mobile) || this.password.length < 6) { throw new Error('请输入11位手机号和至少6位密码'); }
    if (this.authMode !== 0 && this.password !== this.repeatPassword) { throw new Error('两次密码输入不一致'); }
    if (this.authMode === 1 && !this.username.trim()) { throw new Error('请输入用户名'); }
    if (this.authMode !== 0 && (!this.code || (this.authMode === 1 && !this.agreed))) { throw new Error('请同意隐私政策并输入验证码'); }
    await this.api.saveURL(this.server);
    const body = new AuthBody(); body.mobile = await encrypt(this.mobile); body.password = await encrypt(this.password);
    if (this.authMode !== 0) { body.verificationCode = this.code; }
    if (this.authMode === 1) { body.username = this.username; body.roles = 'editor'; body.avatar = 'https://lemoncity.oss-cn-shanghai.aliyuncs.com/avatar/avater01.png'; }
    if (this.authMode === 0) {
      const token = await this.api.post<string>('user/login', body);
      if (!token || typeof token !== 'string') { throw new Error('登录未返回有效凭证'); }
      await this.api.saveToken(token); this.password = ''; this.loggedIn = true;
      await this.loadStudy();
    } else {
      await this.api.post<Object>(this.authMode === 1 ? 'user/register' : 'user/change/password', body);
      this.authMode = 0; this.notice = '操作成功，请登录';
    }
  }
  async loadStudy(): Promise<void> {
    this.studyLoaded = false;
    this.user = await this.api.post<User>('user/info');
    const data = await this.api.post<RecordData>('userWordRecord/load');
    const records = JSON.parse(data?.recordComplete || '[]') as Word[];
    if (this.user.vip === 0 && records.length > 200) { throw new Error('普通会员最多学习200个单词'); }
    const pending = records.filter((item: Word) => due(item, Date.now()));
    const queue = pending.length > 0 ? await this.api.post<Word[]>('userWordRecord/load/adv', pending) : [];
    this.records = records; this.queue = queue; this.cursor = 0; this.revealed = false; this.studyLoaded = true;
  }
  async save(records: Word[]): Promise<void> {
    const body = new SaveBody(); body.recordComplete = JSON.stringify(records);
    await this.api.post<Object>('userWordRecord/update', body);
  }
  async grade(delta: number): Promise<void> {
    const current = this.queue[this.cursor];
    const next = JSON.parse(JSON.stringify(this.records)) as Word[];
    const index = next.findIndex((item: Word) => item.word === current.word);
    if (index < 0) { throw new Error('记录与单词不匹配，请刷新'); }
    next[index].level = delta === -99 ? 0 : Math.max(0, Math.min(12, (next[index].level ?? 0) + delta));
    next[index].reviewTime = Date.now();
    await this.save(next); this.records = next; this.cursor++; this.revealed = false; this.editing = false; this.dictionaries = false;
  }
  async saveTranslation(): Promise<void> {
    const next = JSON.parse(JSON.stringify(this.records)) as Word[];
    const index = next.findIndex((item: Word) => item.word === this.queue[this.cursor].word);
    if (index < 0) { throw new Error('记录不存在，请刷新'); }
    next[index].translation = this.translation; await this.save(next); this.records = next;
    const queue = JSON.parse(JSON.stringify(this.queue)) as Word[]; queue[this.cursor].translation = this.translation; this.queue = queue;
    this.notice = '释义已保存';
  }
  async speak(): Promise<void> {
    const body = new SoundBody(); body.soundMark = 'AmericanEnglishMp3/' + this.queue[this.cursor].word + '_us.mp3';
    const url = await this.api.post<string>('userWordRecord/soundMark', body);
    await this.player?.release();
    this.player = await media.createAVPlayer();
    const player = this.player;
    player.on('stateChange', (state: string) => {
      if (state === 'initialized') { player.prepare().catch((error: Error) => { this.notice = error.message; }); }
      if (state === 'prepared') { player.play().catch((error: Error) => { this.notice = error.message; }); }
    });
    player.on('error', () => { this.notice = '发音播放失败，请重试'; });
    player.url = url;
  }
  async openBook(book: Book): Promise<void> {
    const body = new BookBody(); body.id = book.id; body.parentCode = book.parentCode;
    this.words = await this.api.post<Word[]>('library/wordList', body);
    this.selected = []; this.words.forEach((word: Word, index: number) => { if (word.checked) { this.selected.push(index); } });
    this.bookTitle = book.name;
  }
  clear(): void {
    this.api.token = ''; this.loggedIn = false; this.records = []; this.queue = []; this.words = []; this.groups = [];
    this.user = { userId: 0, username: '', vip: 0 }; this.player?.release(); this.player = undefined;
  }
  @Builder
  authView() {
    Column({ space: 16 }) {
      Image('https://lemoncity.oss-cn-shanghai.aliyuncs.com/logo/firefox_word.png').width(66).height(66).margin({ bottom: 24 })
      TextInput({ placeholder: '请输入手机号', text: this.mobile }).height(48).borderRadius(6).backgroundColor('#F9F9F9').type(InputType.PhoneNumber).onChange((v: string) => { this.mobile = v; })
      if (this.authMode === 1) { TextInput({ placeholder: '请输入用户名', text: this.username }).height(48).borderRadius(6).onChange((v: string) => { this.username = v; }) }
      TextInput({ placeholder: '请输入密码', text: this.password }).height(48).borderRadius(6).backgroundColor('#F9F9F9').type(InputType.Password).onChange((v: string) => { this.password = v; })
      if (this.authMode !== 0) {
        TextInput({ placeholder: '确认密码', text: this.repeatPassword }).height(48).borderRadius(6).type(InputType.Password).onChange((v: string) => { this.repeatPassword = v; })
        Row({ space: 8 }) {
          TextInput({ placeholder: '验证码', text: this.code }).layoutWeight(1).onChange((v: string) => { this.code = v; })
          Button(this.countdown > 0 ? this.countdown + '秒后重试' : '发送验证码', { type: ButtonType.Normal }).height(40).fontSize(14).padding({ left: 14, right: 14 }).enabled(this.countdown === 0).backgroundColor('#EAF6F3').fontColor('#287F73').borderRadius(10).onClick(() => { this.execute(async () => {
            if (!/^\d{11}$/.test(this.mobile)) { throw new Error('请输入11位手机号'); }
            const body = new MobileBody(); body.mobile = await encrypt(this.mobile);
            await this.api.post<Object>('user/sendCode', body);
            this.countdown = 60;
            this.countdownTimer = setInterval(() => { this.countdown--; if (this.countdown <= 0) { clearInterval(this.countdownTimer); } }, 1000);
            this.notice = '验证码已发送';
          }); })
        }
      }
      Button(this.authMode === 0 ? '登陆' : this.authMode === 1 ? '注册' : '修改密码').width('100%').height(48).borderRadius(4).backgroundColor('#26A69A').margin({ top: 16 }).onClick(() => { this.execute(async () => { await this.authenticate(); }); })
      if (this.authMode === 0) {
        Text('立即注册').fontSize(14).fontColor('#666666').margin({ top: 14 }).onClick(() => { this.privacyRegistration = true; this.showingPrivacy = true; })
        Text('忘记密码').fontSize(14).fontColor('#666666').margin({ top: 14 }).onClick(() => { this.authMode = 2; })
      } else { Text('已有账号去登陆').fontSize(14).fontColor('#666666').onClick(() => { this.authMode = 0; }) }
    }.padding({ left: 40, right: 40, top: 40, bottom: 40 }).width('100%').constraintSize({ minHeight: '90%' }).justifyContent(FlexAlign.Center)
  }
  @Builder
  studyView() {
    Column({ space: 20 }) {
      if (!this.studyLoaded) {
        Text('学习记录尚未加载，请点击重试').fontColor('#8B9E98').padding(32).onClick(() => { this.execute(async () => { await this.loadStudy(); }); })
      } else if (this.cursor < this.queue.length) {
        Text(this.queue[this.cursor].word).fontSize(36).fontWeight(FontWeight.Bold).fontColor('#67C23A').margin({ top: 30 })
        Row({ space: 12 }) {
          Text('美[' + (this.queue[this.cursor].vocabulary?.usPhonetic ?? '') + ']').fontColor('#666666')
          Image($r('app.media.speaker')).width(36).height(36).padding(6).backgroundColor('#F0F9EB').borderRadius(18).accessibilityText('播放单词发音').onClick(() => { this.execute(async () => { await this.speak(); }); })
        }
        if (this.revealed) {
          if (this.queue[this.cursor].translation) { Text('个人').fontColor('#339999').width('100%'); Text(this.queue[this.cursor].translation ?? '').width('100%') }
          Text('官方').fontColor('#339999').width('100%')
          Text(officialDefinition(this.queue[this.cursor])).width('100%').fontSize(18)
          Text('例句').fontColor('#339999').width('100%')
          Text((this.queue[this.cursor].vocabulary?.sentence ?? '').replace(/<[^>]+>/g, '')).width('100%')
          Text('短语').fontColor('#339999').width('100%')
          Text(phrases(this.queue[this.cursor])).width('100%')
          Row({ space: 28 }) {
            Text('编辑释义').fontColor('#339999').onClick(() => { this.translation = this.queue[this.cursor].translation ?? ''; this.editing = true; })
            Text('查词典').fontColor('#339999').onClick(() => { this.dictionaries = true; })
          }
          if (this.editing) {
            TextArea({ placeholder: '自定义释义', text: this.translation }).onChange((v: string) => { this.translation = v; })
            Row({ space: 20 }) {
              Button('取消', { type: ButtonType.Normal }).height(40).padding({ left: 18, right: 18 }).borderRadius(10).fontSize(14).fontColor('#55736A').backgroundColor('#EDF3F0').onClick(() => { this.editing = false; })
              Button('确定', { type: ButtonType.Normal }).height(40).padding({ left: 20, right: 20 }).backgroundColor('#EAF6F3').fontColor('#287F73').borderRadius(10).onClick(() => { this.execute(async () => { await this.saveTranslation(); this.editing = false; }); })
            }
          }
          if (this.dictionaries) {
            Row({ space: 24 }) {
              ForEach(['金山', '欧路', '有道'], (name: string) => {
                Text(name).fontColor('#339999').onClick(() => {
                  const base = name === '金山' ? 'https://m.iciba.com/' : name === '欧路' ? 'https://dict.eudic.net/mdicts/en/' : 'https://m.youdao.com/dict?le=eng&q=';
                  (getContext(this) as common.UIAbilityContext).startAbility({ action: 'ohos.want.action.viewData', uri: base + encodeURIComponent(this.queue[this.cursor].word) }).catch(() => { this.notice = '无法打开词典'; });
                  this.dictionaries = false;
                })
              })
            }
          }
        } else {
          Column() { Text('点击查看释义').fontColor('#999999') }.width('100%').height(260).backgroundColor('#FFFFFF').justifyContent(FlexAlign.Center).onClick(() => { this.revealed = true; this.execute(async () => { await this.speak(); }); })
        }
        Row({ space: 20 }) {
          Button('认识').layoutWeight(1).fontColor('#67C23A').backgroundColor('#F0F9EB').borderRadius(4).onClick(() => { this.execute(async () => { await this.grade(1); }); })
          Button('模糊').layoutWeight(1).fontColor('#E6A23C').backgroundColor('#FDF6EC').borderRadius(4).onClick(() => { this.execute(async () => { await this.grade(-1); }); })
          Button('忘记').layoutWeight(1).fontColor('#F56C6C').backgroundColor('#FEF0F0').borderRadius(4).onClick(() => { this.execute(async () => { await this.grade(-99); }); })
        }.width('100%').margin({ top: 24 })
      } else {
        Image($r('app.media.mission_complete')).width(180).height(180).objectFit(ImageFit.Contain).margin({ top: 80 })
        Text('任务完成').fontSize(24).fontColor('#339999')
      }
    }.padding(24).width('100%')
  }
  @Builder
  settingsRow(title: string, icon: string, danger: boolean = false) {
    Row({ space: 14 }) {
      Text(icon).fontSize(18).fontColor(danger ? '#C45B50' : '#339999').width(36).height(36).textAlign(TextAlign.Center).backgroundColor(danger ? '#FFF1EF' : '#EAF6F3').borderRadius(10)
      Text(title).fontSize(16).fontColor(danger ? '#C45B50' : '#253C38').layoutWeight(1)
      Text('›').fontSize(22).fontColor('#A4B4AF')
    }.width('100%').padding(14).backgroundColor('#FFFFFF').borderRadius(14)
  }
  @Builder
  libraryView() {
    Column({ space: 16 }) {
      Row() { Text(this.bookTitle ? '单词列表' : '词库').fontSize(28); Blank(); Button(this.bookTitle ? '返回词库' : '刷新', { type: ButtonType.Normal }).height(36).padding({ left: 14, right: 14 }).borderRadius(10).fontSize(14).fontColor('#339999').backgroundColor('#EAF6F3').onClick(() => { this.bookTitle = ''; this.execute(async () => { this.groups = await this.api.post<LibraryGroup[]>('library/pageList'); }); }) }.width('100%')
      if (this.bookTitle) {
        Button('全选', { type: ButtonType.Normal }).height(40).padding({ left: 18, right: 18 }).borderRadius(10).fontSize(14).fontColor('#55736A').backgroundColor('#EDF3F0').onClick(() => { this.selected = this.words.map((word: Word, index: number) => index); })
        ForEach(this.words, (word: Word, index: number) => {
          Row() {
            Checkbox().select(this.selected.includes(index)).onChange((v: boolean) => { this.selected = v ? this.selected.concat([index]) : this.selected.filter((i: number) => i !== index); })
            Text(word.word).fontSize(20)
          }.width('100%')
        })
        Button('保存', { type: ButtonType.Normal }).height(44).padding({ left: 24, right: 24 }).borderRadius(12).fontSize(15).fontWeight(FontWeight.Medium).fontColor('#287F73').backgroundColor('#EAF6F3').enabled(this.selected.length > 0).onClick(() => { this.execute(async () => {
          const chosen = this.selected.map((index: number) => { const word = this.words[index]; word.checked = true; return word; });
          const result = await this.api.post<number>('library/saveCheckedWord', chosen);
          if (result === -1 || result === -2) { throw new Error(result === -1 ? '已超过会员单词额度' : '已超过最大单词上限'); }
          this.bookTitle = ''; this.tab = 0; await this.loadStudy();
        }); })
      } else {
        ForEach(this.groups, (group: LibraryGroup) => {
          Row({ space: 12 }) {
            Text('▤').fontSize(23).fontColor('#339999').width(42).height(42).textAlign(TextAlign.Center).backgroundColor('#EAF6F3').borderRadius(12)
            Column({ space: 4 }) {
              Text(group.desc).fontSize(17).fontWeight(FontWeight.Medium).fontColor('#253C38').width('100%')
              Text(group.subLibrary.length + ' 本词书').fontSize(12).fontColor('#8B9E98').width('100%')
            }.layoutWeight(1)
            Text(this.expanded.includes(group.id) ? '−' : '+').fontSize(22).fontColor('#339999')
          }.width('100%').padding(16).backgroundColor('#FFFFFF').borderRadius(16).onClick(() => { this.expanded = this.expanded.includes(group.id) ? this.expanded.filter((id: number) => id !== group.id) : this.expanded.concat([group.id]); })
          if (this.expanded.includes(group.id)) {
          ForEach(group.subLibrary, (book: Book) => {
            Row() { Text(book.name).fontSize(16).fontColor('#3D5650').layoutWeight(1); Text('›').fontColor('#A4B4AF').fontSize(20) }.width('100%').padding({ left: 20, right: 20, top: 16, bottom: 16 }).backgroundColor('#FFFFFF').borderRadius(12).onClick(() => { this.execute(async () => { await this.openBook(book); }); })
          })
          }
        })
      }
      if (!this.bookTitle) { Text('自定义词书网址：http://47.97.107.100:8055').fontSize(11).fontColor('#8B9E98').margin({ top: 12 }) }
    }.padding(20).width('100%').constraintSize({ minHeight: '100%' }).backgroundColor('#F5F8F7')
  }
  @Builder
  accountView() {
    Column({ space: 20 }) {
      Text('我的').fontSize(28).fontWeight(FontWeight.Bold).fontColor('#253C38').width('100%')
      Row({ space: 18 }) {
        Image(this.user.avatar || 'https://lemoncity.oss-cn-shanghai.aliyuncs.com/avatar/avater01.png').width(72).height(72).borderRadius(36)
        Column({ space: 10 }) {
          Text(this.user.name || this.user.username || '我的账号').fontSize(22).fontWeight(FontWeight.Bold).fontColor('#253C38').width('100%')
          Text(this.user.vip === 0 ? '普通用户' : 'VIP').fontSize(12).fontColor('#339999').padding({ left: 10, right: 10, top: 4, bottom: 4 }).backgroundColor('#E0F1EB').borderRadius(12)
        }.layoutWeight(1).alignItems(HorizontalAlign.Start)
      }.width('100%').padding(24).backgroundColor('#EAF5F0').borderRadius(20).margin({ bottom: 8 })
      Row() { this.settingsRow('用户意见', '✎') }.width('100%').onClick(() => { this.feedbackOpen = !this.feedbackOpen; })
      if (this.user.vip === 8) {
        Text('设置vip  ›').width('100%').padding(16).onClick(() => { this.vipOpen = !this.vipOpen; })
        if (this.vipOpen) {
          TextInput({ placeholder: '请输入用户名', text: this.vipUsername }).onChange((v: string) => { this.vipUsername = v; })
          Button('确定', { type: ButtonType.Normal }).height(40).padding({ left: 20, right: 20 }).borderRadius(10).fontColor('#287F73').backgroundColor('#EAF6F3').onClick(() => { this.execute(async () => {
            const body = new VipBody(); body.username = this.vipUsername;
            await this.api.post<Object>('user/setting/vip', body); this.vipOpen = false; this.notice = this.vipUsername + '设置vip成功';
          }); })
        }
      }
      if (this.feedbackOpen) {
      TextArea({ placeholder: '建议与反馈', text: this.feedback }).onChange((v: string) => { this.feedback = v; })
      Button('提交反馈', { type: ButtonType.Normal }).height(44).padding({ left: 24, right: 24 }).borderRadius(12).fontSize(15).fontWeight(FontWeight.Medium).fontColor('#287F73').backgroundColor('#EAF6F3').enabled(this.feedback.length > 0).onClick(() => { this.execute(async () => {
        const body = new FeedbackBody(); body.userId = this.user.userId; body.content = this.feedback;
        await this.api.post<Object>('suggest/insert', body); this.feedback = ''; this.notice = '感谢反馈';
      }); })
      }
      Row() { this.settingsRow('会员说明', '☆') }.width('100%').onClick(() => { this.showingVIP = true; })
      Row() { this.settingsRow('隐私政策', '◇') }.width('100%').onClick(() => { this.showingPrivacy = true; })
      Row() { this.settingsRow('登出', '↗') }.width('100%').onClick(() => { this.execute(async () => { await this.api.post<Object>('user/logout'); await this.api.saveToken(''); this.clear(); }); })
      Row() { this.settingsRow('注销用户', '−', true) }.width('100%').onClick(() => {
        AlertDialog.show({ title: '注销账号', message: '注销将删除账号，是否继续？',
          primaryButton: { value: '取消', action: () => {} },
          secondaryButton: { value: '确认注销', action: () => { this.execute(async () => {
            const body = new RemoveBody(); body.id = this.user.userId;
            await this.api.post<Object>('user/removal', body); await this.api.saveToken(''); this.clear();
          }); } }
        });
      })
      Text('官网：www.redfox18.com').fontSize(12).fontColor('#999999')
    }.padding(20).width('100%').constraintSize({ minHeight: '100%' }).backgroundColor('#F5F8F7')
  }
  build() {
    Column() {
      if (this.showingVIP) {
        Button('返回', { type: ButtonType.Normal }).height(40).padding({ left: 18, right: 18 }).borderRadius(10).fontSize(14).fontColor('#55736A').backgroundColor('#EDF3F0').onClick(() => { this.showingVIP = false; })
        Scroll() { Column({ space: 24 }) {
          Text('支付宝二维码').fontSize(24)
          Image($r('app.media.vip_qrcode')).width(280).height(280).objectFit(ImageFit.Contain)
          Text('请在支付备注中填写用户名，一个工作日左右开通。如未开通，请联系QQ客服：1760612965')
          Text('单词年度VIP ¥88\n听力与单词年度双VIP ¥158')
          Text('以上内容沿用原项目会员说明。')
        }.padding(24) }.layoutWeight(1)
      } else if (this.showingPrivacy) {
        Button('返回', { type: ButtonType.Normal }).height(40).padding({ left: 18, right: 18 }).borderRadius(10).fontSize(14).fontColor('#55736A').backgroundColor('#EDF3F0').onClick(() => { this.showingPrivacy = false; this.privacyRegistration = false; })
        Scroll() { Text(privacyText).padding(24) }.layoutWeight(1)
        if (this.privacyRegistration) {
          Row({ space: 24 }) {
            Button('拒绝', { type: ButtonType.Normal }).height(40).padding({ left: 18, right: 18 }).borderRadius(10).fontSize(14).fontColor('#55736A').backgroundColor('#EDF3F0').onClick(() => { this.showingPrivacy = false; this.privacyRegistration = false; })
            Button('同意', { type: ButtonType.Normal }).height(40).padding({ left: 20, right: 20 }).backgroundColor('#EAF6F3').fontColor('#287F73').borderRadius(10).onClick(() => { this.agreed = true; this.authMode = 1; this.showingPrivacy = false; this.privacyRegistration = false; })
          }.padding(16)
        }
      } else {
        if (this.notice) { Text(this.notice).fontColor('#A33E32').padding(12).width('100%') }
        if (this.busy) { LoadingProgress().width(32).height(32) }
        Scroll() {
          Column() {
            if (!this.ready || this.busy) {
              Column() { LoadingProgress().width(32).height(32).color('#339999') }.width('100%').height(400).justifyContent(FlexAlign.Center)
            } else if (!this.loggedIn) { this.authView() }
            else if (this.tab === 0) { this.studyView() }
            else if (this.tab === 1) { this.libraryView() }
            else { this.accountView() }
          }.width('100%').enabled(this.ready && !this.busy)
        }.layoutWeight(1).width('100%')
        if (this.loggedIn) {
          Row({ space: 10 }) {
            Button('单词' + (this.queue.length > this.cursor ? ' · ' + (this.queue.length - this.cursor) : ''), { type: ButtonType.Normal }).fontColor(this.tab === 0 ? '#67C23A' : '#909399').backgroundColor(this.tab === 0 ? '#F0F9EB' : '#F5F7FA').height(44).borderRadius(14).fontSize(15).fontWeight(FontWeight.Medium).layoutWeight(1).onClick(() => { this.tab = 0; this.execute(async () => { await this.loadStudy(); }); })
            Button('词库', { type: ButtonType.Normal }).fontColor(this.tab === 1 ? '#67C23A' : '#909399').backgroundColor(this.tab === 1 ? '#F0F9EB' : '#F5F7FA').height(44).borderRadius(14).fontSize(15).fontWeight(FontWeight.Medium).layoutWeight(1).onClick(() => { this.tab = 1; this.execute(async () => { this.groups = await this.api.post<LibraryGroup[]>('library/pageList'); }); })
            Button('我的', { type: ButtonType.Normal }).fontColor(this.tab === 2 ? '#67C23A' : '#909399').backgroundColor(this.tab === 2 ? '#F0F9EB' : '#F5F7FA').height(44).borderRadius(14).fontSize(15).fontWeight(FontWeight.Medium).layoutWeight(1).onClick(() => { this.tab = 2; this.execute(async () => { this.user = await this.api.post<User>('user/info'); }); })
          }.padding(12).width('100%').enabled(!this.busy)
        }
      }
    }.height('100%').width('100%').backgroundColor('#FFFFFF')
  }
}
