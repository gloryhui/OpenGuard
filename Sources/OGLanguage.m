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
            @"apply_all": @"Apply All Now",
            @"monitor_auto": @"Automatically restore changed handlers", @"start_login": @"Start OpenGuard at login",
            @"menu_open": @"Open OpenGuard…", @"menu_apply": @"Apply Rules Now", @"menu_quit": @"Quit OpenGuard",
            @"menu_status_protected": @"OpenGuard: all configured rules are protected",
            @"menu_status_attention": @"OpenGuard: one or more rules need attention",
            @"choose_title": @"Choose the application for .%@ files", @"choose": @"Choose",
            @"invalid_app": @"The selected item is not a valid macOS application.",
            @"protected": @"Protected ✓", @"restored": @"Restored ✓", @"repair_failed": @"Repair failed",
            @"none": @"None", @"changed": @"Changed: %@",
            @"login_error": @"Unable to update the login item.", @"language": @"Language:",
            @"file_type": @"File type", @"open_with": @"Open with",
            @"add_group": @"Add Group", @"add_rule": @"Add Rule", @"remove_group": @"Remove Group",
            @"settings": @"Settings", @"check_updates": @"Check for Updates", @"about": @"About",
            @"restore_groups": @"Initialize Groups…", @"delete_group": @"Delete Group",
            @"rename_group": @"Rename Group", @"new_group": @"New Group", @"ungrouped": @"Root",
            @"add_rule_destination": @"Add to: %@", @"rule_extension_placeholder": @"Extension",
            @"rule_name_placeholder": @"Display name (optional)", @"cancel": @"Cancel", @"add": @"Add",
            @"invalid_extension": @"Enter a valid file extension without spaces or path characters.",
            @"duplicate_rule": @"A rule for .%@ already exists.",
            @"initialize_groups_warning_title": @"Initialize all groups?",
            @"initialize_groups_warning_message": @"This removes every existing group and recreates the default groups. Existing rules and application bindings are preserved and reorganized. Proceed carefully.",
            @"initialize_groups_confirm": @"Initialize Groups",
            @"choose_app_tooltip": @"Choose an application", @"inherited_app": @"Inherited: %@",
            @"picker_search": @"Search by application name, Bundle ID, or path",
            @"picker_application": @"Application", @"picker_bundle": @"Bundle ID",
            @"picker_location": @"Location", @"picker_cancel": @"Cancel",
            @"picker_count": @"%lu applications",
            @"update_available": @"OpenGuard update available",
            @"update_message": @"Version %@ is available on GitHub Releases.",
            @"update_view_release": @"View Release", @"update_later": @"Later",
            @"checking_updates": @"Checking…", @"update_check_failed": @"Unable to check for updates. Please try again later.",
            @"up_to_date_title": @"OpenGuard is up to date", @"up_to_date_message": @"You are using the latest released version.",
            @"no_release_title": @"No published release", @"no_release_message": @"GitHub does not currently have a published OpenGuard release to compare against.",
            @"about_message": @"Version %@\nA lightweight macOS utility that protects your default file applications.\n\nPolyForm Noncommercial 1.0.0", @"ok": @"OK",
            @"partial_apps": @"Individual: %lu/%lu", @"multiple_apps": @"Multiple applications",
            @"not_set": @"Not set", @"not_configured": @"Not configured",
            @"group_status": @"%lu protected · %lu/%lu configured",
            @"choose_group_app": @"Choose one application for %@",
            @"group_summary": @"%lu groups · %lu/%lu rules protected · %lu restorations",
            @"group_developer_text": @"Text & Source Code",
            @"group_documents": @"Documents & Reading",
            @"group_images": @"Images", @"group_media": @"Audio & Video",
            @"group_archives": @"Archives", @"group_custom": @"Custom"
        },
        @"zh-Hans": @{
            @"tagline": @"默认应用，牢牢锁定。", @"checking": @"正在检查规则…",
            @"extension": @"文件后缀", @"application": @"指定应用", @"status": @"状态",
            @"apply_all": @"立即应用全部规则",
            @"monitor_auto": @"默认应用被修改后自动恢复", @"start_login": @"登录时启动 OpenGuard",
            @"menu_open": @"打开 OpenGuard…", @"menu_apply": @"立即应用规则", @"menu_quit": @"退出 OpenGuard",
            @"menu_status_protected": @"OpenGuard：全部已配置规则均受保护",
            @"menu_status_attention": @"OpenGuard：有规则需要处理",
            @"choose_title": @"选择用于打开 .%@ 文件的应用", @"choose": @"选择",
            @"invalid_app": @"所选项目不是有效的 macOS 应用。",
            @"protected": @"保护中 ✓", @"restored": @"已恢复 ✓", @"repair_failed": @"恢复失败",
            @"none": @"无", @"changed": @"已被修改：%@",
            @"login_error": @"无法更新登录启动项。", @"language": @"语言：",
            @"file_type": @"文件类型", @"open_with": @"打开方式",
            @"add_group": @"添加分组", @"add_rule": @"添加规则", @"remove_group": @"移除分组",
            @"settings": @"设置", @"check_updates": @"检查更新", @"about": @"关于",
            @"restore_groups": @"初始化分组…", @"delete_group": @"删除分组",
            @"rename_group": @"重命名分组", @"new_group": @"新建分组", @"ungrouped": @"根目录",
            @"add_rule_destination": @"添加到：%@", @"rule_extension_placeholder": @"后缀名",
            @"rule_name_placeholder": @"显示名称（可选）", @"cancel": @"取消", @"add": @"添加",
            @"invalid_extension": @"请输入有效的文件后缀，不能包含空格或路径字符。",
            @"duplicate_rule": @".%@ 的规则已经存在。",
            @"initialize_groups_warning_title": @"确定初始化全部分组？",
            @"initialize_groups_warning_message": @"此操作会移除所有现有分组，并重新创建默认分组。现有规则和应用绑定会保留并重新归类，请谨慎操作。",
            @"initialize_groups_confirm": @"初始化分组",
            @"choose_app_tooltip": @"选择应用", @"inherited_app": @"继承分组：%@",
            @"picker_search": @"按应用名称、Bundle ID 或安装路径搜索",
            @"picker_application": @"应用", @"picker_bundle": @"Bundle ID",
            @"picker_location": @"安装位置", @"picker_cancel": @"取消",
            @"picker_count": @"共 %lu 个应用",
            @"update_available": @"OpenGuard 有新版本",
            @"update_message": @"版本 %@ 已在 GitHub Releases 发布。",
            @"update_view_release": @"查看发布页", @"update_later": @"稍后",
            @"checking_updates": @"检查中…", @"update_check_failed": @"无法检查更新，请稍后重试。",
            @"up_to_date_title": @"OpenGuard 已是最新版本", @"up_to_date_message": @"你正在使用 GitHub 上最新发布的版本。",
            @"no_release_title": @"暂无正式版本", @"no_release_message": @"GitHub 当前没有可供比较的 OpenGuard 正式 Release。",
            @"about_message": @"版本 %@\n用于保护文件默认打开方式的轻量 macOS 工具。\n\nPolyForm Noncommercial 1.0.0", @"ok": @"好",
            @"partial_apps": @"单项设置 %lu/%lu", @"multiple_apps": @"多个应用",
            @"not_set": @"未设置", @"not_configured": @"未配置",
            @"group_status": @"已保护 %lu · 已配置 %lu/%lu",
            @"choose_group_app": @"为“%@”统一选择应用",
            @"group_summary": @"%lu 个分组 · 已保护 %lu/%lu 条规则 · 已恢复 %lu 次",
            @"group_developer_text": @"文本与源代码",
            @"group_documents": @"文档与阅读",
            @"group_images": @"图片", @"group_media": @"音频与视频",
            @"group_archives": @"压缩文件", @"group_custom": @"自定义"
        },
        @"ja": @{
            @"tagline": @"既定のアプリをしっかり固定。", @"checking": @"ルールを確認中…",
            @"extension": @"拡張子", @"application": @"指定アプリ", @"status": @"状態",
            @"apply_all": @"すべて適用",
            @"monitor_auto": @"変更された既定アプリを自動復元", @"start_login": @"ログイン時に OpenGuard を起動",
            @"menu_open": @"OpenGuard を開く…", @"menu_apply": @"今すぐルールを適用", @"menu_quit": @"OpenGuard を終了",
            @"menu_status_protected": @"OpenGuard：設定済みルールはすべて保護されています",
            @"menu_status_attention": @"OpenGuard：確認が必要なルールがあります",
            @"choose_title": @".%@ ファイルを開くアプリを選択", @"choose": @"選択",
            @"invalid_app": @"選択した項目は有効な macOS アプリではありません。",
            @"protected": @"保護中 ✓", @"restored": @"復元済み ✓", @"repair_failed": @"復元失敗",
            @"none": @"なし", @"changed": @"変更済み：%@",
            @"login_error": @"ログイン項目を更新できません。", @"language": @"言語：",
            @"file_type": @"ファイル形式", @"open_with": @"このアプリで開く",
            @"add_group": @"グループを追加", @"add_rule": @"ルールを追加", @"remove_group": @"グループを解除",
            @"settings": @"設定", @"check_updates": @"更新を確認", @"about": @"情報",
            @"restore_groups": @"グループを初期化…", @"delete_group": @"グループを削除",
            @"rename_group": @"グループ名を変更", @"new_group": @"新規グループ", @"ungrouped": @"ルート",
            @"add_rule_destination": @"追加先：%@", @"rule_extension_placeholder": @"拡張子",
            @"rule_name_placeholder": @"表示名（任意）", @"cancel": @"キャンセル", @"add": @"追加",
            @"invalid_extension": @"空白やパス文字を含まない有効な拡張子を入力してください。",
            @"duplicate_rule": @".%@ のルールは既に存在します。",
            @"initialize_groups_warning_title": @"すべてのグループを初期化しますか？",
            @"initialize_groups_warning_message": @"既存のグループをすべて削除し、既定のグループを再作成します。ルールとアプリの割り当ては保持して再分類されます。慎重に実行してください。",
            @"initialize_groups_confirm": @"グループを初期化",
            @"choose_app_tooltip": @"アプリを選択", @"inherited_app": @"グループから継承：%@",
            @"picker_search": @"アプリ名、Bundle ID、またはパスで検索",
            @"picker_application": @"アプリ", @"picker_bundle": @"Bundle ID",
            @"picker_location": @"場所", @"picker_cancel": @"キャンセル",
            @"picker_count": @"%lu 個のアプリ",
            @"update_available": @"OpenGuard の更新があります",
            @"update_message": @"バージョン %@ が GitHub Releases で公開されています。",
            @"update_view_release": @"リリースを表示", @"update_later": @"後で",
            @"checking_updates": @"確認中…", @"update_check_failed": @"更新を確認できません。後でもう一度お試しください。",
            @"up_to_date_title": @"OpenGuard は最新です", @"up_to_date_message": @"最新の公開バージョンを使用しています。",
            @"no_release_title": @"公開リリースがありません", @"no_release_message": @"GitHub に比較対象となる OpenGuard の公開リリースがありません。",
            @"about_message": @"バージョン %@\n既定のファイルアプリを保護する軽量 macOS ユーティリティ。\n\nPolyForm Noncommercial 1.0.0", @"ok": @"OK",
            @"partial_apps": @"個別設定 %lu/%lu", @"multiple_apps": @"複数のアプリ",
            @"not_set": @"未設定", @"not_configured": @"未構成",
            @"group_status": @"%lu 件保護 · %lu/%lu 件設定",
            @"choose_group_app": @"「%@」の共通アプリを選択",
            @"group_summary": @"%lu グループ · %lu/%lu 件保護 · %lu 回復元",
            @"group_developer_text": @"テキストとソースコード",
            @"group_documents": @"文書と閲覧",
            @"group_images": @"画像", @"group_media": @"音声と動画",
            @"group_archives": @"アーカイブ", @"group_custom": @"カスタム"
        },
        @"ko": @{
            @"tagline": @"기본 앱을 확실하게 고정합니다.", @"checking": @"규칙 확인 중…",
            @"extension": @"확장자", @"application": @"지정 앱", @"status": @"상태",
            @"apply_all": @"모두 적용",
            @"monitor_auto": @"변경된 기본 앱 자동 복원", @"start_login": @"로그인 시 OpenGuard 시작",
            @"menu_open": @"OpenGuard 열기…", @"menu_apply": @"지금 규칙 적용", @"menu_quit": @"OpenGuard 종료",
            @"menu_status_protected": @"OpenGuard: 설정된 모든 규칙이 보호되고 있습니다",
            @"menu_status_attention": @"OpenGuard: 확인이 필요한 규칙이 있습니다",
            @"choose_title": @".%@ 파일을 열 앱 선택", @"choose": @"선택",
            @"invalid_app": @"선택한 항목은 올바른 macOS 앱이 아닙니다.",
            @"protected": @"보호됨 ✓", @"restored": @"복원됨 ✓", @"repair_failed": @"복원 실패",
            @"none": @"없음", @"changed": @"변경됨: %@",
            @"login_error": @"로그인 항목을 업데이트할 수 없습니다.", @"language": @"언어:",
            @"file_type": @"파일 형식", @"open_with": @"연결 앱",
            @"add_group": @"그룹 추가", @"add_rule": @"규칙 추가", @"remove_group": @"그룹 제거",
            @"settings": @"설정", @"check_updates": @"업데이트 확인", @"about": @"정보",
            @"restore_groups": @"그룹 초기화…", @"delete_group": @"그룹 삭제",
            @"rename_group": @"그룹 이름 변경", @"new_group": @"새 그룹", @"ungrouped": @"루트",
            @"add_rule_destination": @"추가 위치: %@", @"rule_extension_placeholder": @"확장자",
            @"rule_name_placeholder": @"표시 이름(선택)", @"cancel": @"취소", @"add": @"추가",
            @"invalid_extension": @"공백이나 경로 문자가 없는 올바른 확장자를 입력하세요.",
            @"duplicate_rule": @".%@ 규칙이 이미 있습니다.",
            @"initialize_groups_warning_title": @"모든 그룹을 초기화할까요?",
            @"initialize_groups_warning_message": @"기존 그룹을 모두 제거하고 기본 그룹을 다시 만듭니다. 기존 규칙과 앱 연결은 보존되어 다시 분류됩니다. 신중하게 진행하세요.",
            @"initialize_groups_confirm": @"그룹 초기화",
            @"choose_app_tooltip": @"앱 선택", @"inherited_app": @"그룹에서 상속: %@",
            @"picker_search": @"앱 이름, Bundle ID 또는 경로로 검색",
            @"picker_application": @"애플리케이션", @"picker_bundle": @"Bundle ID",
            @"picker_location": @"위치", @"picker_cancel": @"취소",
            @"picker_count": @"앱 %lu개",
            @"update_available": @"OpenGuard 업데이트 사용 가능",
            @"update_message": @"버전 %@이 GitHub Releases에 공개되었습니다.",
            @"update_view_release": @"릴리스 보기", @"update_later": @"나중에",
            @"checking_updates": @"확인 중…", @"update_check_failed": @"업데이트를 확인할 수 없습니다. 나중에 다시 시도하세요.",
            @"up_to_date_title": @"OpenGuard가 최신입니다", @"up_to_date_message": @"최신 공개 버전을 사용하고 있습니다.",
            @"no_release_title": @"공개 릴리스 없음", @"no_release_message": @"GitHub에 비교할 수 있는 OpenGuard 공개 릴리스가 없습니다.",
            @"about_message": @"버전 %@\n기본 파일 앱을 보호하는 가벼운 macOS 유틸리티입니다.\n\nPolyForm Noncommercial 1.0.0", @"ok": @"확인",
            @"partial_apps": @"개별 설정 %lu/%lu", @"multiple_apps": @"여러 애플리케이션",
            @"not_set": @"설정 안 됨", @"not_configured": @"미설정",
            @"group_status": @"%lu개 보호 · %lu/%lu개 설정",
            @"choose_group_app": @"%@ 그룹의 공통 앱 선택",
            @"group_summary": @"%lu개 그룹 · %lu/%lu개 규칙 보호 · %lu회 복원",
            @"group_developer_text": @"텍스트 및 소스 코드",
            @"group_documents": @"문서 및 읽기",
            @"group_images": @"이미지", @"group_media": @"오디오 및 비디오",
            @"group_archives": @"압축 파일", @"group_custom": @"사용자 지정"
        },
        @"es": @{
            @"tagline": @"Tus aplicaciones predeterminadas, siempre protegidas.", @"checking": @"Comprobando reglas…",
            @"extension": @"Extensión", @"application": @"Aplicación asignada", @"status": @"Estado",
            @"apply_all": @"Aplicar todas",
            @"monitor_auto": @"Restaurar automáticamente los cambios", @"start_login": @"Iniciar OpenGuard al entrar",
            @"menu_open": @"Abrir OpenGuard…", @"menu_apply": @"Aplicar reglas ahora", @"menu_quit": @"Salir de OpenGuard",
            @"menu_status_protected": @"OpenGuard: todas las reglas configuradas están protegidas",
            @"menu_status_attention": @"OpenGuard: hay reglas que requieren atención",
            @"choose_title": @"Elige la aplicación para archivos .%@", @"choose": @"Elegir",
            @"invalid_app": @"El elemento seleccionado no es una aplicación válida de macOS.",
            @"protected": @"Protegida ✓", @"restored": @"Restaurada ✓", @"repair_failed": @"Error al restaurar",
            @"none": @"Ninguna", @"changed": @"Cambiada: %@",
            @"login_error": @"No se pudo actualizar el inicio de sesión.", @"language": @"Idioma:",
            @"file_type": @"Tipo de archivo", @"open_with": @"Abrir con",
            @"add_group": @"Añadir grupo", @"add_rule": @"Añadir regla", @"remove_group": @"Quitar grupo",
            @"settings": @"Ajustes", @"check_updates": @"Buscar actualizaciones", @"about": @"Acerca de",
            @"restore_groups": @"Inicializar grupos…", @"delete_group": @"Eliminar grupo",
            @"rename_group": @"Renombrar grupo", @"new_group": @"Nuevo grupo", @"ungrouped": @"Raíz",
            @"add_rule_destination": @"Añadir a: %@", @"rule_extension_placeholder": @"Extensión",
            @"rule_name_placeholder": @"Nombre visible (opcional)", @"cancel": @"Cancelar", @"add": @"Añadir",
            @"invalid_extension": @"Introduce una extensión válida sin espacios ni caracteres de ruta.",
            @"duplicate_rule": @"Ya existe una regla para .%@.",
            @"initialize_groups_warning_title": @"¿Inicializar todos los grupos?",
            @"initialize_groups_warning_message": @"Esto elimina todos los grupos existentes y vuelve a crear los grupos predeterminados. Las reglas y asociaciones se conservan y reorganizan. Procede con cuidado.",
            @"initialize_groups_confirm": @"Inicializar grupos",
            @"choose_app_tooltip": @"Elegir una aplicación", @"inherited_app": @"Heredada: %@",
            @"picker_search": @"Buscar por nombre, Bundle ID o ruta",
            @"picker_application": @"Aplicación", @"picker_bundle": @"Bundle ID",
            @"picker_location": @"Ubicación", @"picker_cancel": @"Cancelar",
            @"picker_count": @"%lu aplicaciones",
            @"update_available": @"Actualización de OpenGuard disponible",
            @"update_message": @"La versión %@ está disponible en GitHub Releases.",
            @"update_view_release": @"Ver versión", @"update_later": @"Más tarde",
            @"checking_updates": @"Buscando…", @"update_check_failed": @"No se pudo buscar actualizaciones. Inténtalo de nuevo más tarde.",
            @"up_to_date_title": @"OpenGuard está actualizado", @"up_to_date_message": @"Estás usando la última versión publicada.",
            @"no_release_title": @"No hay una versión publicada", @"no_release_message": @"GitHub no tiene actualmente una versión publicada de OpenGuard para comparar.",
            @"about_message": @"Versión %@\nUtilidad ligera para proteger las aplicaciones predeterminadas en macOS.\n\nPolyForm Noncommercial 1.0.0", @"ok": @"Aceptar",
            @"partial_apps": @"Ajustes individuales: %lu/%lu", @"multiple_apps": @"Varias aplicaciones",
            @"not_set": @"Sin asignar", @"not_configured": @"Sin configurar",
            @"group_status": @"%lu protegidas · %lu/%lu configuradas",
            @"choose_group_app": @"Elige una aplicación para %@",
            @"group_summary": @"%lu grupos · %lu/%lu reglas protegidas · %lu restauraciones",
            @"group_developer_text": @"Texto y código fuente",
            @"group_documents": @"Documentos y lectura",
            @"group_images": @"Imágenes", @"group_media": @"Audio y vídeo",
            @"group_archives": @"Archivos comprimidos", @"group_custom": @"Personalizado"
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
