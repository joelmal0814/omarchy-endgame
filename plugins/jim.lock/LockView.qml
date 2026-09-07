import QtQuick
import QtQuick.Effects
import Quickshell
import qs.Commons
import qs.Ui

// Endgame lock view. Presentation-only clone of omarchy.lock's LockView.qml:
// Service.qml (PAM/session-lock logic) is untouched. Everything themed here
// comes from shell.toml — [lock] for the input colours and an optional
// [branding] section (see ~/.config/omarchy/themes/endgame/README.md):
//   lock-background  file in the theme's backgrounds/ dir ("" = current wallpaper)
//   lock-blur        0..1 blur strength (0 = sharp)
//   lock-dim         0..1 dark overlay strength
//   lock-icon        small glyph inside the password field
//   lock-subtitle    line under the clock
//   lock-brand       bottom-left caption
//   lock-status      bottom-right caption
//   lock-time-format / lock-date-format   Qt date format strings
Item {
  id: root

  property string backgroundPath: ""
  property int backgroundVersion: 0
  property bool fingerprintConfigured: false
  property bool authenticatingPassword: false
  property string failureMessage: ""
  property int failedAttempts: 0
  property bool inputEnabled: true
  property bool loadBackground: true
  property string passwordText: ""
  property bool syncingPasswordText: false

  // ---- Theme tokens -------------------------------------------------------

  // shell.toml values are ASCII-only (see the theme's shell.branding.toml);
  // glyphs arrive as \uXXXX escapes and are decoded here.
  function decodeEscapes(value) {
    return String(value || "").replace(/\\u\{?([0-9a-fA-F]{4,6})\}?/g, function(match, hex) {
      return String.fromCodePoint(parseInt(hex, 16))
    })
  }

  function brand(key, fallback) {
    var v = Color.shellValues["branding." + key]
    return (typeof v === "string" && v.trim().length > 0) ? decodeEscapes(v).trim() : fallback
  }
  function brandNumber(key, fallback) {
    var v = Color.shellValues["branding." + key]
    if (typeof v !== "string" || v.trim().length === 0) return fallback
    var n = Number(v)
    return isFinite(n) ? Math.max(0, Math.min(1, n)) : fallback
  }

  readonly property string lockBackgroundName: brand("lock-background", "")
  readonly property string themedBackgroundPath: lockBackgroundName.length > 0 ? Color.currentThemePath + "/backgrounds/" + lockBackgroundName : ""
  property bool themedBackgroundFailed: false
  readonly property string effectiveBackgroundPath: (themedBackgroundPath.length > 0 && !themedBackgroundFailed) ? themedBackgroundPath : backgroundPath
  readonly property real blurAmount: brandNumber("lock-blur", 1.0)
  readonly property real dimAmount: brandNumber("lock-dim", 0.0)
  readonly property string iconText: brand("lock-icon", "")
  readonly property string subtitleText: brand("lock-subtitle", "")
  readonly property string brandText: brand("lock-brand", "")
  readonly property string statusText: brand("lock-status", "")
  readonly property string timeFormat: brand("lock-time-format", "HH:mm")
  readonly property string dateFormat: brand("lock-date-format", "dddd d MMMM")

  onThemedBackgroundPathChanged: themedBackgroundFailed = false

  // ---- Geometry -----------------------------------------------------------
  readonly property string placeholderText: "Enter Password"
  readonly property int fieldWidth: Style.space(272)
  readonly property int fieldHeight: Style.space(38)
  readonly property int outlineThickness: 1
  readonly property int fieldFontSize: Style.font.subtitle
  readonly property int passwordDotFontSize: Math.round(Style.font.body * 1.05)
  readonly property int passwordDotLetterSpacing: Math.round(Style.font.body * 0.25)
  readonly property int clockFontSize: Math.round(Style.font.displayLarge * 3.6)
  readonly property real iconReserve: iconText.length > 0 ? Math.round(chessIcon.implicitWidth + Style.space(10)) : 0
  readonly property real fingerprintReserve: fingerprintConfigured ? Math.round(fingerprintIcon.implicitWidth + Style.space(10)) : 0
  readonly property real sideReserve: Math.max(iconReserve, fingerprintReserve)
  readonly property real passwordDotScale: dotMetrics.advanceWidth > 0
    ? Math.min(1, (passwordInput.width - 4) / dotMetrics.advanceWidth)
    : 1
  readonly property bool showPasswordCursor: inputEnabled && !authenticatingPassword && failureMessage.length === 0
  readonly property bool errorState: failureMessage.length > 0
  readonly property bool activeState: authenticatingPassword || (passwordInput.activeFocus && passwordInput.text.length > 0)
  readonly property color fieldBorderColor: errorState ? Color.lock.borderError : (activeState ? Color.lock.borderActive : Color.lock.border)

  signal submitPassword(string password)
  signal passwordTextEdited(string password)
  signal clearFailureRequested()
  signal wakeRequested()

  function fileUrl(path) {
    if (!path) return ""
    var encoded = String(path).split("/").map(encodeURIComponent).join("/")
    return "file://" + encoded + "?v=" + backgroundVersion
  }

  function forcePasswordFocus() {
    passwordInput.forceActiveFocus()
  }

  function clearPassword() {
    passwordTextEdited("")
  }

  function syncPasswordText() {
    if (passwordInput.text === passwordText) return
    syncingPasswordText = true
    passwordInput.text = passwordText
    syncingPasswordText = false
  }

  onPasswordTextChanged: syncPasswordText()
  onInputEnabledChanged: {
    if (inputEnabled) Qt.callLater(forcePasswordFocus)
  }
  Component.onCompleted: {
    syncPasswordText()
    if (inputEnabled) Qt.callLater(forcePasswordFocus)
  }

  SystemClock {
    id: clock
    precision: SystemClock.Minutes
  }

  TextMetrics {
    id: dotMetrics
    font.family: Style.font.family
    font.pixelSize: root.passwordDotFontSize
    font.letterSpacing: root.passwordDotLetterSpacing
    text: "●".repeat(passwordInput.text.length)
  }

  Rectangle {
    anchors.fill: parent
    color: Color.background

    Image {
      id: wallpaper
      anchors.fill: parent
      source: root.loadBackground ? root.fileUrl(root.effectiveBackgroundPath) : ""
      fillMode: Image.PreserveAspectCrop
      asynchronous: true
      cache: false
      sourceSize.width: width
      sourceSize.height: height
      // Hidden while the blur pass is drawing it; shown directly when blur is off.
      visible: root.blurAmount <= 0
      onStatusChanged: {
        if (status === Image.Error && root.themedBackgroundPath.length > 0 && !root.themedBackgroundFailed) {
          console.log("omarchy lock: themed background missing, falling back to wallpaper: " + root.themedBackgroundPath)
          root.themedBackgroundFailed = true
        }
      }
    }

    MultiEffect {
      anchors.fill: wallpaper
      source: wallpaper
      visible: root.blurAmount > 0
      autoPaddingEnabled: false
      blurEnabled: root.loadBackground && wallpaper.status === Image.Ready && root.blurAmount > 0
      blur: root.blurAmount
      blurMax: 64
      blurMultiplier: 1.0
      contrast: -0.04
    }

    Rectangle {
      anchors.fill: parent
      color: Color.background
      opacity: root.dimAmount
    }

    MouseArea {
      anchors.fill: parent
      hoverEnabled: true
      onClicked: { root.wakeRequested(); root.forcePasswordFocus() }
      onPositionChanged: root.wakeRequested()
    }

    // ---- Centre stack: clock, date, subtitle, input ------------------------
    Column {
      id: centreStack
      anchors.horizontalCenter: parent.horizontalCenter
      anchors.verticalCenter: parent.verticalCenter
      anchors.verticalCenterOffset: -Style.space(24)
      spacing: 0

      Text {
        textFormat: Text.PlainText
        anchors.horizontalCenter: parent.horizontalCenter
        text: Qt.formatTime(clock.date, root.timeFormat)
        color: Color.lock.text
        font.family: Style.font.family
        font.pixelSize: root.clockFontSize
        font.weight: Font.Light
        font.letterSpacing: Math.round(root.clockFontSize * 0.04)
        renderType: Text.NativeRendering
      }

      Item { width: 1; height: Style.space(6) }

      Text {
        textFormat: Text.PlainText
        anchors.horizontalCenter: parent.horizontalCenter
        text: Qt.formatDate(clock.date, root.dateFormat).toUpperCase()
        color: Color.lock.placeholder
        font.family: Style.font.family
        font.pixelSize: Style.font.subtitle
        font.letterSpacing: Style.space(3)
      }

      Item { width: 1; height: Style.space(30); visible: root.subtitleText.length > 0 }

      Text {
        textFormat: Text.PlainText
        anchors.horizontalCenter: parent.horizontalCenter
        visible: root.subtitleText.length > 0
        text: root.subtitleText
        color: Color.accent
        font.family: Style.font.family
        font.pixelSize: Style.font.title
        font.letterSpacing: Style.space(6)
      }

      Item { width: 1; height: Style.space(28) }

      Rectangle {
        id: inputField
        anchors.horizontalCenter: parent.horizontalCenter
        width: root.fieldWidth
        height: root.fieldHeight
        radius: Style.cornerRadius
        color: Color.lock.background
        border.width: root.outlineThickness
        border.color: root.fieldBorderColor
        clip: true

        Behavior on border.color { ColorAnimation { duration: 160 } }

        Text {
          id: chessIcon
          textFormat: Text.PlainText
          anchors.left: parent.left
          anchors.leftMargin: root.outlineThickness + Style.space(12)
          anchors.verticalCenter: parent.verticalCenter
          visible: root.iconText.length > 0
          text: root.iconText
          color: root.errorState ? Color.lock.textError : Color.accent
          font.family: Style.font.family
          font.pixelSize: Style.font.heading
          verticalAlignment: Text.AlignVCenter
        }

        TextInput {
          id: passwordInput
          anchors.fill: parent
          anchors.topMargin: root.outlineThickness
          anchors.bottomMargin: root.outlineThickness
          anchors.leftMargin: root.outlineThickness + Style.space(12) + root.sideReserve
          anchors.rightMargin: root.outlineThickness + Style.space(12) + root.sideReserve
          verticalAlignment: TextInput.AlignVCenter
          horizontalAlignment: TextInput.AlignHCenter
          activeFocusOnPress: true
          clip: true
          enabled: root.inputEnabled && !root.authenticatingPassword
          readOnly: root.authenticatingPassword
          echoMode: TextInput.Password
          passwordCharacter: "●"
          passwordMaskDelay: 0
          color: Color.lock.text
          selectionColor: Color.lock.selection
          selectedTextColor: Color.lock.text
          font.family: Style.font.family
          font.pixelSize: text.length > 0 ? Math.max(1, Math.floor(root.passwordDotFontSize * root.passwordDotScale)) : root.fieldFontSize
          font.letterSpacing: text.length > 0 ? root.passwordDotLetterSpacing * root.passwordDotScale : 0
          cursorVisible: activeFocus && root.showPasswordCursor && text.length > 0
          cursorDelegate: Rectangle {
            width: 1
            color: Color.lock.text
            visible: passwordInput.cursorVisible
          }

          onTextChanged: {
            if (!root.syncingPasswordText) root.passwordTextEdited(text)
            if (text.length > 0) {
              root.wakeRequested()
            }
            if (text.length > 0 && root.failureMessage.length > 0) root.clearFailureRequested()
          }

          onAccepted: {
            var submitted = root.passwordText
            root.passwordTextEdited("")
            if (submitted.length > 0) root.submitPassword(submitted)
          }

          Keys.onPressed: function(event) {
            root.wakeRequested()
            if (event.key === Qt.Key_Escape || (event.modifiers & Qt.ControlModifier && event.key === Qt.Key_U)) {
              root.passwordTextEdited("")
              event.accepted = true
            }
          }
        }

        Text {
          textFormat: Text.PlainText
          anchors.fill: passwordInput
          text: root.authenticatingPassword ? "Checking…" : (root.failureMessage.length > 0 ? root.failureMessage : root.placeholderText)
          visible: passwordInput.text.length === 0
          color: root.authenticatingPassword ? Color.lock.text : (root.failureMessage.length > 0 ? Color.lock.textError : Color.lock.placeholder)
          font.family: Style.font.family
          font.pixelSize: root.fieldFontSize
          font.italic: !root.authenticatingPassword && root.failureMessage.length > 0
          horizontalAlignment: Text.AlignHCenter
          verticalAlignment: Text.AlignVCenter
          elide: Text.ElideRight
        }

        // Fingerprint hint inside the field's right edge when a sensor is enrolled.
        Text {
          id: fingerprintIcon
          objectName: "fingerprintIndicator"
          anchors.right: parent.right
          anchors.rightMargin: root.outlineThickness + Style.space(12)
          anchors.verticalCenter: parent.verticalCenter
          visible: root.fingerprintConfigured
          text: "󰈷"
          color: Color.lock.placeholder
          font.family: Style.font.family
          font.pixelSize: Math.round(root.fieldFontSize * 1.1)
          horizontalAlignment: Text.AlignHCenter
          verticalAlignment: Text.AlignVCenter
        }
      }
    }

    // ---- Corner captions ---------------------------------------------------
    Text {
      textFormat: Text.PlainText
      anchors.left: parent.left
      anchors.bottom: parent.bottom
      anchors.leftMargin: Style.space(32)
      anchors.bottomMargin: Style.space(28)
      visible: root.brandText.length > 0
      text: root.brandText
      color: Color.lock.placeholder
      font.family: Style.font.family
      font.pixelSize: Style.font.caption
      font.letterSpacing: Style.space(2)
    }

    Text {
      textFormat: Text.PlainText
      anchors.right: parent.right
      anchors.bottom: parent.bottom
      anchors.rightMargin: Style.space(32)
      anchors.bottomMargin: Style.space(28)
      visible: root.statusText.length > 0
      text: root.statusText
      color: Color.lock.placeholder
      font.family: Style.font.family
      font.pixelSize: Style.font.caption
      font.letterSpacing: Style.space(2)
    }
  }
}
