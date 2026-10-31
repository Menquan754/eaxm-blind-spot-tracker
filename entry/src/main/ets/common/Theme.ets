/**
 * 主题色板：浅色 / 深色 两套语义色，darkMode 由 AppStorage('darkMode') 驱动
 */
export interface ThemeColors {
  primary: string;
  bg: string;
  card: string;
  panel: string;
  sidebarBg: string;
  chipBg: string;
  selectedBg: string;
  text: string;
  subText: string;
  muted: string;
  border: string;
  ok: string;
  bad: string;
  warn: string;
  okBg: string;
  okText: string;
  dangerBg: string;
  dangerBorder: string;
  chart1: string;
  chart2: string;
  chart3: string;
  chart4: string;
}

const LIGHT: ThemeColors = {
  primary: '#0A59F7',
  bg: '#F1F3F5',
  card: '#FFFFFF',
  panel: '#F7F8FB',
  sidebarBg: '#FAFBFC',
  chipBg: '#EEF0F5',
  selectedBg: '#E8F0FF',
  text: '#182431',
  subText: '#555555',
  muted: '#86909C',
  border: '#EDF0F5',
  ok: '#00B96B',
  bad: '#F5313D',
  warn: '#FF8800',
  okBg: '#EAF8F0',
  okText: '#27AE60',
  dangerBg: '#FFF1F0',
  dangerBorder: '#FFD6D2',
  chart1: '#0A59F7',
  chart2: '#00B96B',
  chart3: '#FF8800',
  chart4: '#7B61FF'
};

const DARK: ThemeColors = {
  primary: '#5B8CFF',
  bg: '#0F1115',
  card: '#1A1D23',
  panel: '#23272F',
  sidebarBg: '#15181E',
  chipBg: '#2A2F38',
  selectedBg: '#20304D',
  text: '#E8EAED',
  subText: '#AEB4BC',
  muted: '#7C828C',
  border: '#2E333C',
  ok: '#3DD68C',
  bad: '#FF6B6B',
  warn: '#FFB020',
  okBg: '#1B3628',
  okText: '#4ADE80',
  dangerBg: '#3A2026',
  dangerBorder: '#5C3038',
  chart1: '#5B8CFF',
  chart2: '#3DD68C',
  chart3: '#FFB020',
  chart4: '#9D8CFF'
};

export function themeOf(dark: boolean): ThemeColors {
  return dark ? DARK : LIGHT;
}

/** 从 AppStorage 读取当前深色模式 */
export function isDarkNow(): boolean {
  const v = AppStorage.get<boolean>('darkMode');
  return v === true;
}

/**
 * 三态主题模式：0=跟随系统 1=浅色 2=深色
 * AppStorage('themeMode') 持久化用户选择；AppStorage('sysDark') 为系统当前深色状态（由 EntryAbility 监听刷新）
 */
export function effectiveDark(themeMode: number, sysDark: boolean): boolean {
  if (themeMode === 2) {
    return true;
  }
  if (themeMode === 1) {
    return false;
  }
  return sysDark;
}

/** 依据 themeMode/sysDark 重新计算并写回 darkMode，供各页面 @StorageLink('darkMode') 响应 */
export function syncThemeToDark(): void {
  const mode = AppStorage.get<number>('themeMode') ?? 0;
  const sysDark = AppStorage.get<boolean>('sysDark') === true;
  AppStorage.setOrCreate('darkMode', effectiveDark(mode, sysDark));
}
