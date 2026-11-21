import { http } from '@kit.NetworkKit';
import { cryptoFramework } from '@kit.CryptoArchitectureKit';
import { util } from '@kit.ArkTS';
import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';

export interface Vocabulary { usPhonetic?: string; content?: string; sentence?: string; }
export interface Word { id?: number; word: string; level?: number; reviewTime?: number; translation?: string; checked?: boolean; vocabulary?: Vocabulary; }
export interface Book { id: number; name: string; parentCode: string; }
export interface LibraryGroup { id: number; desc: string; subLibrary: Book[]; }
export interface User { userId: number; username: string; name?: string; avatar?: string; vip: number; }
export interface RecordData { recordComplete?: string; }
export interface Basic { explains?: string[]; }
export interface Phrase { key: string; value: string[]; }
export interface DictionaryContent { basic?: Basic; web?: Phrase[]; }
interface Envelope<T> { code?: number; status?: number; errorCode?: number; subCode?: number; subMessage?: string; errorMessage?: string; data: T; }
export class EmptyBody {}
export class MobileBody { mobile: string = ''; }
export class AuthBody { mobile: string = ''; password: string = ''; verificationCode?: string; username?: string; roles?: string; avatar?: string; }
export class BookBody { id: number = 0; parentCode: string = ''; }
export class SaveBody { recordComplete: string = ''; }
export class SoundBody { soundMark: string = ''; }
export class FeedbackBody { userId: number = 0; content: string = ''; }
export class RemoveBody { id: number = 0; }
export class VipBody { username: string = ''; }

export class Api {
  baseURL: string = 'http://47.97.107.100:8088/api/';
  token: string = '';
  private prefs?: preferences.Preferences;
  async init(context: common.UIAbilityContext): Promise<void> {
    this.prefs = await preferences.getPreferences(context, { name: 'panda_settings' });
    this.baseURL = await this.prefs.get('apiURL', this.baseURL) as string;
    // Session only: do not persist the bearer token in unencrypted preferences.
  }
  async saveURL(value: string): Promise<void> {
    this.baseURL = value;
    await this.prefs?.put('apiURL', value); await this.prefs?.flush();
  }
  async post<T>(endpoint: string, body: Object = new EmptyBody()): Promise<T> {
    if (!/^https?:\/\//.test(this.baseURL)) { throw new Error('接口地址无效'); }
    const client = http.createHttp();
    try {
      const response = await client.request(this.baseURL.replace(/\/+$/, '') + '/' + endpoint.replace(/^\/+/, ''), {
        method: http.RequestMethod.POST,
        header: { 'Content-Type': 'application/json', 'token': this.token },
        extraData: JSON.stringify(body), connectTimeout: 20000, readTimeout: 20000,
        expectDataType: http.HttpDataType.STRING
      });
      if (response.responseCode < 200 || response.responseCode >= 300) { throw new Error('服务器请求失败：' + response.responseCode); }
      const result = JSON.parse(response.result as string) as Envelope<T>;
      if (result.errorCode === 1000 && result.subCode === 1) { this.token = ''; throw new Error('登录已过期，请重新登录'); }
      if (result.code !== 200 && result.status !== 0) { throw new Error(result.subMessage || result.errorMessage || '请求失败'); }
      return result.data;
    } finally { client.destroy(); }
  }
}
export async function encrypt(text: string): Promise<string> {
  const keyBytes = new util.TextEncoder().encodeInto('gww417038_x8888x');
  const bytes = new util.TextEncoder().encodeInto(text);
  const padded = new Uint8Array(Math.ceil(bytes.length / 16) * 16); padded.set(bytes);
  const generator = cryptoFramework.createSymKeyGenerator('AES128');
  const key = await generator.convertKey({ data: keyBytes });
  const cipher = cryptoFramework.createCipher('AES128|CBC|NoPadding');
  const params: cryptoFramework.IvParamsSpec = { algName: 'IvParamsSpec', iv: { data: keyBytes } };
  await cipher.init(cryptoFramework.CryptoMode.ENCRYPT_MODE, key, params);
  const result = await cipher.doFinal({ data: padded });
  return new util.Base64Helper().encodeToStringSync(result.data);
}
export const intervals: number[] = [1,1,2,4,7,15,30,45,60,90,135,180,210,270,300,365,545,730,1095,1460];
export function due(item: Word, now: number): boolean {
  const level = item.level ?? 0;
  return level >= 0 && level < intervals.length && now - (item.reviewTime ?? 0) >= intervals[level] * 86400000;
}
export function definition(item: Word): string {
  if (!item.vocabulary?.content) { return ''; }
  try { const content = JSON.parse(item.vocabulary.content) as DictionaryContent; const explains = content.basic?.explains ?? []; const phrases = (content.web ?? []).map((entry: Phrase) => entry.key + '：' + entry.value.join('；')); return explains.concat(phrases).join('\n'); } catch { return ''; }
}
export function officialDefinition(item: Word): string {
  try { return ((JSON.parse(item.vocabulary?.content || '{}') as DictionaryContent).basic?.explains ?? []).join('\n'); } catch { return ''; }
}
export function phrases(item: Word): string {
  try { return ((JSON.parse(item.vocabulary?.content || '{}') as DictionaryContent).web ?? []).map((entry: Phrase) => entry.key + '：' + entry.value.join('；')).join('\n'); } catch { return ''; }
}
