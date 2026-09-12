<p align="center">
  <img src="docs/open-guard-hero.png" alt="파일 기본 연결을 보호하는 OpenGuard" width="100%">
</p>

<p align="center">
  <a href="README.md">简体中文</a> · <a href="README.en.md">English</a> · <a href="README.ja.md">日本語</a> · <strong>한국어</strong> · <a href="README.es.md">Español</a>
</p>

# OpenGuard

OpenGuard는 파일 확장자를 사용자가 선택한 앱에 안정적으로 연결해 주는 가벼운 네이티브 macOS 메뉴 막대 유틸리티입니다. 다른 앱이 기본 연결을 변경하면 OpenGuard가 규칙을 자동으로 복원합니다.

## 만든 이유

`.md` 파일을 Visual Studio Code로 지정해도 얼마 뒤 Xcode나 다른 앱이 연결을 다시 가져가는 구체적인 불편에서 시작했습니다. Finder의 “항상 이 앱으로 열기”는 한 번 수정할 뿐, 다음 변경까지 막지는 못합니다.

OpenGuard는 관리자 권한이나 무거운 백그라운드 서비스 없이 사용자의 선택을 유지합니다.

## 주요 장점

- 텍스트와 소스 코드, 문서, 이미지, 미디어, 압축 파일로 정리된 33개 확장자 프리셋.
- 그룹 전체에 앱 하나를 지정하고 필요한 확장자만 개별 재정의.
- 그룹과 규칙 추가, 드래그 정렬과 그룹 간 이동, 우클릭 그룹 이름 변경. 그룹을 제거해도 규칙은 루트에 안전하게 유지.
- 현지화 이름, 원래 이름, Bundle ID 또는 경로로 앱 검색.
- 3초마다 자동 복원하고 잠자기 해제 및 앱 활성화 시 즉시 확인.
- 타사 런타임이 없는 네이티브 AppKit 구현.
- 简体中文, English, 日本語, 한국어, Español 등 5개 UI 언어.
- macOS 10.13 이상, Intel 및 Apple Silicon 지원.
- 관리자 권한 불필요. 로그인 실행은 사용자 수준 LaunchAgent 사용.
- 시작할 때와 이후 매시간 GitHub Releases를 비동기로 확인.

## 사용법

1. `OpenGuard.app`을 `/Applications`로 이동합니다.
2. 상단 버튼에서 그룹이나 규칙을 추가하고 드래그하여 정렬하거나 다른 그룹 및 루트로 이동합니다.
3. 그룹의 `…`에서 공통 앱을, 확장자의 `…`에서 개별 앱을 선택합니다. 그룹 이름은 우클릭으로 바꿀 수 있습니다.
4. 필요하면 로그인 실행을 켜고 자동 복원을 유지합니다. 그룹 초기화는 상단 “설정” 메뉴에 있으며 실행 전에 확인합니다.

## 작동 방식과 한계

macOS Launch Services 및 UTI를 통해 파일 핸들러를 읽고 설정합니다. 커널 수준에서 변경을 차단하지 않고, 변경을 감지한 뒤 빠르게 복원하므로 가볍고 권한이 높은 구성 요소가 필요하지 않습니다.

## 업데이트 확인

시작할 때 한 번, 실행 중에는 매시간 GitHub의 최신 Release를 비동기로 확인합니다. 같은 새 버전은 실행당 한 번만 알리고, 네트워크 오류나 Release가 없을 때는 조용히 건너뜁니다. 자동 다운로드나 설치는 하지 않습니다.

## 빌드

macOS 10.13 이상과 Xcode Command Line Tools가 필요합니다.

```sh
make clean verify
```

유니버설 앱은 `build/OpenGuard.app`에 생성됩니다.

Applications로 드래그할 수 있는 DMG, 예비 ZIP 및 SHA-256 체크섬을 생성합니다.

```sh
make clean package
```

## 개인정보 보호

원격 측정, 광고, 추적이 없습니다. 규칙, 파일 이름, 파일 목록 또는 앱 목록을 업로드하지 않습니다. 유일한 네트워크 요청은 GitHub API에서 공개 Release 메타데이터를 가져오는 것입니다.

## 아트워크

아이콘과 README 대표 이미지는 OpenGuard 전용의 독창적인 텍스트 프롬프트로 제작했습니다. 참조 이미지, 스톡 소재, 타사 상표 또는 기존 앱 로고를 사용하지 않았습니다. 자세한 내용은 [ARTWORK.md](ARTWORK.md)를 참고하세요.

## 라이선스

[PolyForm Noncommercial License 1.0.0](https://polyformproject.org/licenses/noncommercial/1.0.0)에 따른 source-available 소프트웨어입니다. 비상업적 열람, 수정, Fork 및 재배포는 허용되지만 상업적 이용은 허용되지 않습니다.
