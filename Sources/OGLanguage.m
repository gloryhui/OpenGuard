#import "OGLanguage.h"

static NSString * const OGLanguageDefaultsKey = @"languageCode";

@implementation OGLanguage

+ (instancetype)shared {
    static OGLanguage *instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ instance = [[self alloc] init]; });
    return instance;
}

+ (NSArray<NSDictionary<NSString *,NSString *> *> *)supportedLanguages {
    return @[
        @{@"code": @"zh-Hans", @"name": @"简体中文"},
        @{@"code": @"en", @"name": @"English"},
        @{@"code": @"ja", @"name": @"日本語"},
        @{@"code": @"ko", @"name": @"한국어"},
        @{@"code": @"es", @"name": @"Español"}
    ];
}

- (instancetype)init {
    self = [super init];
    if (!self) return nil;
    NSString *saved = [[NSUserDefaults standardUserDefaults] stringForKey:OGLanguageDefaultsKey];
    if (saved) {
        _code = saved;
    } else {
        NSString *preferred = [NSLocale preferredLanguages].firstObject ?: @"en";
        if ([preferred hasPrefix:@"zh"]) _code = @"zh-Hans";
        else if ([preferred hasPrefix:@"ja"]) _code = @"ja";
        else if ([preferred hasPrefix:@"ko"]) _code = @"ko";
        else if ([preferred hasPrefix:@"es"]) _code = @"es";
        else _code = @"en";
    }
    return self;
}

- (void)setCode:(NSString *)code {
    BOOL supported = NO;
    for (NSDictionary *language in [OGLanguage supportedLanguages]) {
        if ([language[@"code"] isEqualToString:code]) { supported = YES; break; }
    }
    _code = supported ? [code copy] : @"en";
    [[NSUserDefaults standardUserDefaults] setObject:_code forKey:OGLanguageDefaultsKey];
}

+ (NSDictionary<NSString *, NSDictionary<NSString *, NSString *> *> *)translations {
    return @{
        @"en": @{
            @"tagline": @"Default apps, held in place.", @"checking": @"Checking rules…",
            @"extension": @"Extension", @"application": @"Required application", @"status": @"Status",
            @"add_rule": @"＋ Add Rule", @"remove": @"－ Remove", @"apply_all": @"Apply All Now",
            @"monitor_auto": @"Automatically restore changed handlers", @"start_login": @"Start OpenGuard at login",
            @"menu_open": @"Open OpenGuard…", @"menu_apply": @"Apply Rules Now", @"menu_quit": @"Quit OpenGuard",
            @"add_title": @"Choose a filename extension", @"add_info": @"Select a common file type or choose Custom.",
            @"choose_app": @"Choose Application…", @"cancel": @"Cancel", @"custom": @"Custom…",
            @"custom_title": @"Custom filename extension", @"custom_info": @"Enter an extension, with or without the leading dot.",
            @"invalid_extension": @"Please enter a valid extension using letters or numbers only.",
            @"choose_title": @"Choose the application for .%@ files", @"choose": @"Choose",
            @"invalid_app": @"The selected item is not a valid macOS application.",
            @"protected": @"Protected ✓", @"restored": @"Restored ✓", @"repair_failed": @"Repair failed",
            @"none": @"None", @"changed": @"Changed: %@",
            @"no_rules": @"No rules yet. Add one to start protecting a file type.",
            @"summary": @"%lu of %lu rules protected · %lu automatic restorations this run",
            @"login_error": @"Unable to update the login item.", @"language": @"Language:"
        },
        @"zh-Hans": @{
            @"tagline": @"默认应用，牢牢锁定。", @"checking": @"正在检查规则…",
            @"extension": @"文件后缀", @"application": @"指定应用", @"status": @"状态",
            @"add_rule": @"＋ 添加规则", @"remove": @"－ 删除", @"apply_all": @"立即应用全部规则",
            @"monitor_auto": @"默认应用被修改后自动恢复", @"start_login": @"登录时启动 OpenGuard",
            @"menu_open": @"打开 OpenGuard…", @"menu_apply": @"立即应用规则", @"menu_quit": @"退出 OpenGuard",
            @"add_title": @"选择文件后缀", @"add_info": @"选择常见文件类型，或选择“自定义”。",
            @"choose_app": @"选择应用…", @"cancel": @"取消", @"custom": @"自定义…",
            @"custom_title": @"自定义文件后缀", @"custom_info": @"输入后缀名，可带或不带开头的点。",
            @"invalid_extension": @"请输入仅包含字母或数字的有效后缀名。",
            @"choose_title": @"选择用于打开 .%@ 文件的应用", @"choose": @"选择",
            @"invalid_app": @"所选项目不是有效的 macOS 应用。",
            @"protected": @"保护中 ✓", @"restored": @"已恢复 ✓", @"repair_failed": @"恢复失败",
            @"none": @"无", @"changed": @"已被修改：%@",
            @"no_rules": @"暂无规则。添加一条规则即可开始保护。",
            @"summary": @"已保护 %lu/%lu 条规则 · 本次运行已自动恢复 %lu 次",
            @"login_error": @"无法更新登录启动项。", @"language": @"语言："
        },
        @"ja": @{
            @"tagline": @"既定のアプリをしっかり固定。", @"checking": @"ルールを確認中…",
            @"extension": @"拡張子", @"application": @"指定アプリ", @"status": @"状態",
            @"add_rule": @"＋ ルールを追加", @"remove": @"－ 削除", @"apply_all": @"すべて適用",
            @"monitor_auto": @"変更された既定アプリを自動復元", @"start_login": @"ログイン時に OpenGuard を起動",
            @"menu_open": @"OpenGuard を開く…", @"menu_apply": @"今すぐルールを適用", @"menu_quit": @"OpenGuard を終了",
            @"add_title": @"ファイル拡張子を選択", @"add_info": @"一般的な種類またはカスタムを選択してください。",
            @"choose_app": @"アプリを選択…", @"cancel": @"キャンセル", @"custom": @"カスタム…",
            @"custom_title": @"カスタム拡張子", @"custom_info": @"先頭のドットの有無にかかわらず拡張子を入力します。",
            @"invalid_extension": @"英数字のみの有効な拡張子を入力してください。",
            @"choose_title": @".%@ ファイルを開くアプリを選択", @"choose": @"選択",
            @"invalid_app": @"選択した項目は有効な macOS アプリではありません。",
            @"protected": @"保護中 ✓", @"restored": @"復元済み ✓", @"repair_failed": @"復元失敗",
            @"none": @"なし", @"changed": @"変更済み：%@",
            @"no_rules": @"ルールがありません。追加して保護を開始してください。",
            @"summary": @"%lu/%lu 件を保護中 · 今回の自動復元 %lu 回",
            @"login_error": @"ログイン項目を更新できません。", @"language": @"言語："
        },
        @"ko": @{
            @"tagline": @"기본 앱을 확실하게 고정합니다.", @"checking": @"규칙 확인 중…",
            @"extension": @"확장자", @"application": @"지정 앱", @"status": @"상태",
            @"add_rule": @"＋ 규칙 추가", @"remove": @"－ 삭제", @"apply_all": @"모두 적용",
            @"monitor_auto": @"변경된 기본 앱 자동 복원", @"start_login": @"로그인 시 OpenGuard 시작",
            @"menu_open": @"OpenGuard 열기…", @"menu_apply": @"지금 규칙 적용", @"menu_quit": @"OpenGuard 종료",
            @"add_title": @"파일 확장자 선택", @"add_info": @"일반 파일 형식 또는 사용자 지정을 선택하세요.",
            @"choose_app": @"앱 선택…", @"cancel": @"취소", @"custom": @"사용자 지정…",
            @"custom_title": @"사용자 지정 확장자", @"custom_info": @"앞의 점 유무와 관계없이 확장자를 입력하세요.",
            @"invalid_extension": @"영문자나 숫자로 된 올바른 확장자를 입력하세요.",
            @"choose_title": @".%@ 파일을 열 앱 선택", @"choose": @"선택",
            @"invalid_app": @"선택한 항목은 올바른 macOS 앱이 아닙니다.",
            @"protected": @"보호됨 ✓", @"restored": @"복원됨 ✓", @"repair_failed": @"복원 실패",
            @"none": @"없음", @"changed": @"변경됨: %@",
            @"no_rules": @"아직 규칙이 없습니다. 규칙을 추가하여 보호를 시작하세요.",
            @"summary": @"%lu/%lu개 규칙 보호 중 · 이번 실행에서 %lu회 자동 복원",
            @"login_error": @"로그인 항목을 업데이트할 수 없습니다.", @"language": @"언어:"
        },
        @"es": @{
            @"tagline": @"Tus aplicaciones predeterminadas, siempre protegidas.", @"checking": @"Comprobando reglas…",
            @"extension": @"Extensión", @"application": @"Aplicación asignada", @"status": @"Estado",
            @"add_rule": @"＋ Añadir regla", @"remove": @"－ Eliminar", @"apply_all": @"Aplicar todas",
            @"monitor_auto": @"Restaurar automáticamente los cambios", @"start_login": @"Iniciar OpenGuard al entrar",
            @"menu_open": @"Abrir OpenGuard…", @"menu_apply": @"Aplicar reglas ahora", @"menu_quit": @"Salir de OpenGuard",
            @"add_title": @"Elige una extensión", @"add_info": @"Selecciona un tipo común o Personalizada.",
            @"choose_app": @"Elegir aplicación…", @"cancel": @"Cancelar", @"custom": @"Personalizada…",
            @"custom_title": @"Extensión personalizada", @"custom_info": @"Escribe la extensión con o sin el punto inicial.",
            @"invalid_extension": @"Introduce una extensión válida con letras o números.",
            @"choose_title": @"Elige la aplicación para archivos .%@", @"choose": @"Elegir",
            @"invalid_app": @"El elemento seleccionado no es una aplicación válida de macOS.",
            @"protected": @"Protegida ✓", @"restored": @"Restaurada ✓", @"repair_failed": @"Error al restaurar",
            @"none": @"Ninguna", @"changed": @"Cambiada: %@",
            @"no_rules": @"Aún no hay reglas. Añade una para comenzar la protección.",
            @"summary": @"%lu de %lu reglas protegidas · %lu restauraciones automáticas en esta sesión",
            @"login_error": @"No se pudo actualizar el inicio de sesión.", @"language": @"Idioma:"
        }
    };
}

- (NSString *)text:(NSString *)key {
    NSDictionary *all = [OGLanguage translations];
    return all[self.code][key] ?: all[@"en"][key] ?: key;
}

- (BOOL)hasCompleteTranslations {
    NSDictionary *all = [OGLanguage translations];
    NSSet *reference = [NSSet setWithArray:[all[@"en"] allKeys]];
    for (NSDictionary *language in [all allValues]) {
        if (![[NSSet setWithArray:[language allKeys]] isEqualToSet:reference]) return NO;
    }
    return YES;
}

@end
