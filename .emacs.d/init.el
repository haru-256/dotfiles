(require 'package)
;; MELPAを追加
(add-to-list 'package-archives '("melpa" . "https://melpa.org/packages/") t)
;; MELPA-stableを追加
(add-to-list 'package-archives '("melpa-stable" . "https://stable.melpa.org/packages/") t)
;; Marmaladeを追加  エラー?
;;(add-to-list 'package-archives  '("marmalade" . "https://marmalade-repo.org/packages/") t)
;; Orgを追加
(add-to-list 'package-archives '("org" . "http://orgmode.org/elpa/") t)

;; 初期化
(package-initialize)
;; frameの大きさを文字数で指定
(setq default-frame-alist
  '(
    (width . 130)
    (height . 120)
   ))
;; 補完パケージ
(require 'company)
(global-company-mode) ; 全バッファで有効にする
(setq company-idle-delay 0) ; デフォルトは0.5
(setq company-minimum-prefix-length 3) ; デフォルトは4
(setq company-selection-wrap-around t) ; 候補の一番下でさらに下に行こうとすると一番上に戻る


;;カッコの対応補完
(electric-pair-mode 1)
(add-hook 'python-mode-hook
         (lambda ()
           (define-key python-mode-map "\"" 'electric-pair)
            (define-key python-mode-map "\'" 'electric-pair)
           (define-key python-mode-map "(" 'electric-pair)
            (define-key python-mode-map "[" 'electric-pair)
            (define-key python-mode-map "{" 'electric-pair)))
(defun electric-pair ()
  "Insert character pair without sournding spaces"
 (interactive)
 (let (parens-require-spaces)
    (insert-pair)))

;;; python 設定
;;PATHの引き継ぎ
;;(exec-path-from-shell-initialize)
;;python-mode
;;(autoload 'python-mode "python-mode" "Python Mode." t)
;;(add-to-list 'auto-mode-alist '("\\.py\\'" . python-mode))
;;(add-to-list 'interpreter-mode-alist '("python" . python-mode))
;;(setq python-shell-interpreter "ipython")
;;(setq python-shell-interpreter-args "--simple-prompt --pprint")

;; jedi設定
;;(require 'epc)
;(require 'auto-complete-config)
;;(require 'python)

;;補完対象とするソースまでのパス
;(setenv "PYTHONPATH" "/Users/yohei/.pyenv/versions/3.6.4/envs/tf/lib/python3.6/site-packages/")

;(Require 'jedi)
;(add-hook 'python-mode-hook 'jedi:setup)
;(setq jedi:complete-on-dot t)
;;(setq jedi:environment-root "jedi")
;;(require 'jedi-core)
;;(setq jedi:complete-on-dot t)
;;(setq jedi:use-shortcuts t)
;;(add-hook 'python-mode-hook 'jedi:setup)
;;(add-to-list 'company-backends 'company-jedi) ; backendに追加

;; jedi-core
;;(defun my/python-mode-hook ()
;;  (add-to-list 'company-backends 'company-jedi))
;;(add-hook 'python-mode-hook 'my/python-mode-hook)

;; elpy
(package-initialize)
(elpy-enable)
;;; 使用する Anaconda の仮想環境を設定
;(defvar venv-default "~/.pyenv/versions/tf")
;;; virtualenv を使っているなら次のようなパス
;; (defvar venv-default "~/.virtualenvs/hoge")
;;; デフォルト環境を有効化
;;(pyvenv-activate venv-default)
(require 'pyenv-mode)
(require 'pyenv-mode-auto)
;;; REPL 環境に IPython を使う
;;(elpy-use-ipython)
;;; 自動補完のバックエンドとして Rope か Jedi を選択
(setq elpy-rpc-backend "jedi")

;; auto-pep8
;;(require 'py-autopep8)
(define-key python-mode-map (kbd "C-c F") 'py-autopep8)          ; バッファ全体のコード整形
(define-key python-mode-map (kbd "C-c f") 'py-autopep8-region)   ; 選択リジョン内のコード整形
(setq py-autopep8-options '("--max-line-length=120"))
;;(setq flycheck-flake8-maximum-line-length 120)
;; 保存時にバッファ全体を自動整形する
(add-hook 'before-save-hook 'py-autopep8-before-save)

;; pythonのコード規約をpep8に
(setq python-check-command "pep8")

;; 保存時にバッファ全体を自動整形する
(add-hook 'before-save-hook 'py-autopep8-before-save)

;;; monokaiテーマに設定
(load-theme 'monokai t)
(set-face-foreground 'font-lock-variable-name-face "white")
;; highlights numeric literals in source code. https://github.com/Fanael/highlight-numbers
(add-hook 'python-mode-hook 'highlight-numbers-mode)


;; 日本語の設定（UTF-8）
(set-language-environment 'Japanese)
(prefer-coding-system 'utf-8)

;;;; 種々雑多な設定
;; Official Emacs 用の設定（inline_patch をあててあります）
 (setq default-input-method "MacOSX")
;; 全角記号類「！”＃＄％＆’（）＝〜｜｀『＋＊』＜＞？＿」を入力できるようにする（Mac Emacs では不要）
; (mac-add-key-passed-to-system 'shift)



;; バックアップファイルを作らないようにする
(setq make-backup-files nil)
;; 括弧の対応関係をハイライト表示
(show-paren-mode nil)
;; 上書き入力
(delete-selection-mode t)
;; ツールバーを表示しないようにする（Official Emacs の場合は 0）
					; (tool-bar-mode 0)

;; スタートアップ画面を表示しないようにする
(setq inhibit-startup-message t)
;; 行間隔を少し広げる
 (set-default 'line-spacing 4)
;; ウィンドウ（フレーム）のサイズ設定する
;;(setq default-frame-alist
;;   '((width . 90) (height . 60)))

;; 背景の不透明度（アクティブウィンドウが95%,非アクティブが95%)
(add-to-list 'default-frame-alist '(alpha . (95 95)))

;; マウス・スクロールを滑らかにする（Mac Emacs 専用）
 (setq mac-mouse-wheel-smooth-scroll t)
;; カーソルの色を設定
; (set-cursor-color "DarkGray")

;;全行インデント整形
(defun all-indent ()
     (interactive)
     (mark-whole-buffer)
     (indent-region (region-beginning)(region-end))
     (point-undo))
(global-set-key (kbd  "C-x C-]") 'all-indent)

;;; highlight-indent-guides
;; https://github.com/DarthFennec/highlight-indent-guides
(add-hook 'prog-mode-hook 'highlight-indent-guides-mode)
(setq highlight-indent-guides-method 'column)

;; メタキーをcommandに設定
(when (eq system-type 'darwin)
  (setq ns-command-modifier (quote meta)))




;; フォントの設定
;; 出典：http://sakito.jp/emacs/emacs23.html



;; 行数を表示する
(global-linum-mode t)      ; デフォルトで linum-mode を有効にする
(setq linum-format "%4d ") ; 4 桁分の領域を確保して行番号のあとにスペースを入れる
(line-number-mode t)	   ;下のバーに行数を表示

;; インデント設定
(add-hook 'c-mode-common-hook
	  (lambda ()
	    (c-set-offset 'case-label '+)
	    ))
(custom-set-variables
 ;; custom-set-variables was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 '(ansi-color-names-vector
   ["#272822" "#F92672" "#A6E22E" "#E6DB74" "#66D9EF" "#FD5FF0" "#A1EFE4" "#F8F8F2"])
 '(avy-migemo-function-names
   (quote
    (swiper--add-overlays-migemo
     (swiper--re-builder :around swiper--re-builder-migemo-around)
     (ivy--regex :around ivy--regex-migemo-around)
     (ivy--regex-or-literal :around ivy--regex-or-literal-migemo-around)
     (ivy--regex-plus :around ivy--regex-plus-migemo-around)
     ivy--highlight-default-migemo ivy-occur-revert-buffer-migemo ivy-occur-press-migemo avy-migemo-goto-char avy-migemo-goto-char-2 avy-migemo-goto-char-in-line avy-migemo-goto-char-timer avy-migemo-goto-subword-1 avy-migemo-goto-word-1 avy-migemo-isearch avy-migemo-org-goto-heading-timer avy-migemo--overlay-at avy-migemo--overlay-at-full)))
 '(compilation-message-face (quote default))
 '(custom-safe-themes
   (quote
    ("12b204c8fcce23885ce58e1031a137c5a14461c6c7e1db81998222f8908006af" "17c2da4329305ecabf96f58d930724f0ac8179305ca9fa2d05c2cd8e1927735a" "8db4b03b9ae654d4a57804286eb3e332725c84d7cdab38463cb6b97d5762ad26" default)))
 '(fci-rule-color "#3C3D37")
 '(highlight-changes-colors (quote ("#FD5FF0" "#AE81FF")))
 '(highlight-tail-colors
   (quote
    (("#3C3D37" . 0)
     ("#679A01" . 20)
     ("#4BBEAE" . 30)
     ("#1DB4D0" . 50)
     ("#9A8F21" . 60)
     ("#A75B00" . 70)
     ("#F309DF" . 85)
     ("#3C3D37" . 100))))
 '(magit-diff-use-overlays nil)
 '(minimap-window-location (quote right))
 '(package-selected-packages
   (quote
    (pyenv-mode virtualenvwrapper py-yapf exec-path-from-shell magit color-theme-solarized php-mode highlight-operators highlight-numbers elpy hiwin company-jedi company avy-migemo swiper-helm counsel ivy minimap paren-completer highlight-indent-guides python-pep8 python-mode wc-mode flycheck color-moccur)))
 '(pos-tip-background-color "#FFFACE")
 '(pos-tip-foreground-color "#272822")
 '(py-force-py-shell-name-p t)
 '(py-ipython-command-args "--simple-prompt -i")
 '(py-shell-name "ipython")
 '(vc-annotate-background nil)
 '(vc-annotate-color-map
   (quote
    ((20 . "#F92672")
     (40 . "#CF4F1F")
     (60 . "#C26C0F")
     (80 . "#E6DB74")
     (100 . "#AB8C00")
     (120 . "#A18F00")
     (140 . "#989200")
     (160 . "#8E9500")
     (180 . "#A6E22E")
     (200 . "#729A1E")
     (220 . "#609C3C")
     (240 . "#4E9D5B")
     (260 . "#3C9F79")
     (280 . "#A1EFE4")
     (300 . "#299BA6")
     (320 . "#2896B5")
     (340 . "#2790C3")
     (360 . "#66D9EF"))))
 '(vc-annotate-very-old-color nil)
 '(weechat-color-list
   (unspecified "#272822" "#3C3D37" "#F70057" "#F92672" "#86C30D" "#A6E22E" "#BEB244" "#E6DB74" "#40CAE4" "#66D9EF" "#FB35EA" "#FD5FF0" "#74DBCD" "#A1EFE4" "#F8F8F2" "#F8F8F0")))
(custom-set-faces
 ;; custom-set-faces was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 '(minimap-active-region-background ((t (:background "#003333")))))

;; Flycheck の設定
;;(add-hook 'after-init-hook #'global-flycheck-mode)
; flycheck-pos-tip
;;(with-eval-after-load 'flycheck
;;  (flycheck-pos-tip-mode))

;;----
;; タイトルバーにフルパス表示
;;----
(setq frame-title-format "%f")

;;----
;; 時計表示
;;----
;; 不採用    ;; 時間を表示
;; 不採用    (display-time)
(setq display-time-day-and-date t)  ;; 曜日・月・日
(setq display-time-24hr-format t)   ;; 24時表示
(display-time-mode t)


;;----
;; ファイルサイズ表示
;;----
(size-indication-mode t)


;; '￥'キーで '\' を入力する
(progn
  (define-key global-map [?¥] [?\\])
  (define-key global-map [?\C-¥] [?\C-\\])
  (define-key global-map [?\M-¥] [?\M-\\])
  (define-key global-map [?\C-\M-¥] [?\C-\M-\\]))


;;; web-mode設定
(when (require 'web-mode nil t)
  ;; 自動的にweb-modeを起動したい拡張子を追加する
  (add-to-list 'auto-mode-alist '("\\.html\\'" . web-mode))
  (add-to-list 'auto-mode-alist '("\\.css\\'" . web-mode))
  (add-to-list 'auto-mode-alist '("\\.js\\'" . web-mode))
  (add-to-list 'auto-mode-alist '("\\.jsx\\'" . web-mode))
  (add-to-list 'auto-mode-alist '("\\.tpl\\.php\\'" . web-mode))
  (add-to-list 'auto-mode-alist '("\\.ctp\\'" . web-mode))
  (add-to-list 'auto-mode-alist '("\\.jsp\\'" . web-mode))
  (add-to-list 'auto-mode-alist '("\\.as[cp]x\\'" . web-mode))
  (add-to-list 'auto-mode-alist '("\\.erb\\'" . web-mode))
  (add-to-list 'auto-mode-alist '("\\.php\\'" . web-mode))
  ;;; web-modeのインデント設定用フック
  ;; (defun web-mode-hook ()
  ;;   "Hooks for Web mode."
  ;;   (setq web-mode-markup-indent-offset 2) ; HTMLのインデイント
  ;;   (setq web-mode-css-indent-offset 2) ; CSSのインデント
  ;;   (setq web-mode-code-indent-offset 2) ; JS, PHP, Rubyなどのインデント
  ;;   (setq web-mode-comment-style 2) ; web-mode内のコメントのインデント
  ;;   (setq web-mode-style-padding 1) ; <style>内のインデント開始レベル
  ;;   (setq web-mode-script-padding 1) ; <script>内のインデント開始レベル
  ;;   )
  ;; (add-hook 'web-mode-hook  'web-mode-hook)
  )
;;;phpの設定
;(require 'php-mode)
;; 日本語ドキュメントを利用するための設定
;(when (require 'php-mode nil t)
;  (setq php-site-url "https://secure.php.net/"
;        php-manual-url 'ja))

;; php-modeのインデント設定
;(defun php-indent-hook ()
;  (setq indent-tabs-mode nil)
;  (setq c-basic-offset 4)
  ;; (c-set-offset 'case-label '+) ; switch文のcaseラベル
;  (c-set-offset 'arglist-intro '+) ; 配列の最初の要素が改行した場合
;  (c-set-offset 'arglist-close 0)) ; 配列の閉じ括弧

;(add-hook 'php-mode-hook 'php-indent-hook)


;;; ミニマップの設定
(require 'minimap)
(add-hook 'prog-mode-hook 'minimap-mode)

;; フォント設定
(set-frame-font "Ricty Discord-15")

;;;Tex
;;
;; YaTeX
;;
(autoload 'yatex-mode "yatex" "Yet Another LaTeX mode" t)
(setq auto-mode-alist
      (append '(("\\.tex$" . yatex-mode)
        ("\\.ltx$" . yatex-mode)
        ("\\.cls$" . yatex-mode)
        ("\\.sty$" . yatex-mode)
        ("\\.clo$" . yatex-mode)
        ("\\.bbl$" . yatex-mode)) auto-mode-alist))
(setq YaTeX-kanji-code nil)
(setq YaTeX-latex-message-code 'utf-8)
(setq YaTeX-use-AMS-LaTeX t)

(setq bibtex-command "pbibtex")
(setq dviprint-command-format "dvipdfmx")
;;
;; Skim との連携
;;
;; inverse search
(require 'server)
(unless (server-running-p) (server-start))
;; forward-search
(setq YaTeX-inhibit-prefix-letter t)
(setq YaTeX-dvi2-command-ext-alist
      '(("TeXworks\\|texworks\\|texstudio\\|mupdf\\|SumatraPDF\\|Preview\\|Skim\\|TeXShop\\|evince\\|atril\\|xreader\\|okular\\|zathura\\|qpdfview\\|Firefox\\|firefox\\|chrome\\|chromium\\|MicrosoftEdge\\|microsoft-edge\\|Adobe\\|Acrobat\\|AcroRd32\\|acroread\\|pdfopen\\|xdg-open\\|open\\|start" . ".pdf")))
(setq dvi2-command "open -a Skim")
(setq tex-pdfview-command "open -a Skim")

;;
;; texファイルを開くと自動でRefTexモード
;;
;(add-hook 'latex-mode-hook 'turn-on-reftex)
(add-hook 'yatex-mode-hook 'turn-on-reftex)

;; ivy設定
(require 'ivy)
(ivy-mode 1)
(setq ivy-use-virtual-buffers t)
(setq enable-recursive-minibuffers t)
(setq ivy-height 30) ;; minibufferのサイズを拡大！（重要）
(setq ivy-extra-directories nil)
(setq ivy-re-builders-alist
      '((t . ivy--regex-plus)))

;; counsel設定
(global-set-key (kbd "M-x") 'counsel-M-x)
(global-set-key (kbd "C-x C-f") 'counsel-find-file) ;; find-fileもcounsel任せ！
(defvar counsel-find-file-ignore-regexp (regexp-opt '("./" "../")))

(global-set-key "\C-s" 'swiper)
(defvar swiper-include-line-number-in-search t) ;; line-numberでも検索可能

;; migemo + swiper（日本語をローマ字検索できるようになる）
(require 'avy-migemo)
(avy-migemo-mode 1)
(require 'avy-migemo-e.g.swiper)

;;(when (require 'hiwin nil t)
;;  (hiwin-activate)                            ;; hiwin-modeを有効化
;;  (set-face-background 'hiwin-face "gray19"))  ;; 非アクティブバッファの背景色を設定

;; Git関連
(require 'magit)
(define-key global-map (kbd "M-g") 'magit-status)
