//
//  MemoTextView.swift
//  MemoTextView-Sample
//
//  Created by kawaharadai on 2019/09/03.
//  Copyright © 2019 kawaharadai. All rights reserved.
//

import UIKit

@IBDesignable class MemoTextView: UITextView {

    // MARK: - Propaty

    private lazy var placeHolderLabel = UILabel(frame: CGRect(x: 15, y: 15, width: 0, height: 0))
    private var keyboardFrame: CGRect?
    private var keyboardAnimationDuration: TimeInterval?
    private let normalFont = UIFont.systemFont(ofSize: 17)
    private let boldFont = UIFont.boldSystemFont(ofSize: 17)

    // placeHolderの内容は、Storyboardから編集できるようにする
    @IBInspectable var placeHolderText: String = "" {
        didSet {
            placeHolderLabel.text = placeHolderText
            placeHolderLabel.sizeToFit()
        }
    }

    // MARK: - override

    /// xibのロード後に呼ばれる
    override func awakeFromNib() {
        super.awakeFromNib()
        setup()
    }

    // MARK: - Private

    private func setup() {
        delegate = self
        textContainerInset = UIEdgeInsets(top: 15, left: 10, bottom: 80, right: 5)
        addPlaceHolder()
        addCloseButtonOnKeyboard()
        isHiddenPlaceHolderIfNeeded()
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow(notification:)), name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide(notification:)), name: UIResponder.keyboardWillHideNotification, object: nil)
    }

    /// PlaceHolder用のラベルを追加する
    private func addPlaceHolder() {
        placeHolderLabel.font = font
        placeHolderLabel.textColor = .lightGray
        placeHolderLabel.sizeToFit()
        addSubview(placeHolderLabel)
    }

    /// PlaceHolderを隠すかどうか
    func isHiddenPlaceHolderIfNeeded() {
        placeHolderLabel.isHidden = !text.isEmpty
    }

    /// キーボードが出る際に走る通知
    ///
    /// - Parameter notification: キーボード情報
    @objc private func keyboardWillShow(notification: Notification) {
        guard let keyboardFrame = (notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue,
            let duration = notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? TimeInterval else { return }
        self.keyboardFrame = keyboardFrame
        self.keyboardAnimationDuration = duration
        adjustInsetBottomWillShowKeyboard(keyboardFrame: keyboardFrame, duration: duration)
    }

    /// キーボードが閉じる際に走る通知
    ///
    /// - Parameter notification: キーボード情報
    @objc private func keyboardWillHide(notification: Notification) {
        guard let duration = notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? TimeInterval else { return }
        adjustInsetBottomWillHideKeyboard(duration: duration)
    }

    /// テキスト領域を上にずらす
    ///
    /// - Parameters:
    ///   - keyboardFrame: キーボードのFrame
    ///   - duration: キーボードの表示アニメーションのduration
    private func adjustInsetBottomWillShowKeyboard(keyboardFrame: CGRect, duration: TimeInterval) {
        UIView.animate(withDuration: duration, animations: { [weak self] in
            guard let self = self else { return }
            self.contentInset.bottom = keyboardFrame.height // keyboardで隠れるようならその分offsetYを調整してくれる
            self.scrollIndicatorInsets.bottom = keyboardFrame.height
            self.layoutIfNeeded()
        })
    }

    /// テキスト領域を上にずらした状態から元の状態に戻す
    ///
    /// - Parameter duration: キーボードの表示アニメーションのduration
    private func adjustInsetBottomWillHideKeyboard(duration: TimeInterval) {
        UIView.animate(withDuration: duration, animations: { [weak self] in
            guard let self = self else { return }
            self.contentInset.bottom = 0
            self.scrollIndicatorInsets.bottom = 0
            self.layoutIfNeeded()
        })
    }

    /// キーボード上に閉じるボタンを追加する
    func addCloseButtonOnKeyboard() {
        let backgroundView = UIView(frame: CGRect(x: 0, y: 0,
                                                  width: UIScreen.main.bounds.width * 0.2, height: 40))
        let buttonWidth = backgroundView.frame.width
        let buttonHeight = backgroundView.frame.height
        let closeButton = UIButton(frame: CGRect(x: UIScreen.main.bounds.width - buttonWidth, y: 0,
                                                 width: buttonWidth, height: buttonHeight))
        closeButton.backgroundColor = .white
        closeButton.setTitle("閉じる", for: .normal)
        closeButton.titleLabel?.font = font
        closeButton.setTitleColor(.darkGray, for: .normal)
        closeButton.addTarget(self, action: #selector(endEditing(sender:)), for: .touchUpInside)
        backgroundView.addSubview(closeButton)
        closeButton.layer.masksToBounds = true
        closeButton.layer.cornerRadius = 10
        inputAccessoryView = backgroundView
    }

    @objc func endEditing(sender: UIButton) {
        endEditing(true)
    }

    private func scrollSelectTextPosition() {
        guard let selectedTextRange = selectedTextRange else { return }
        let caret = caretRect(for: selectedTextRange.end)
        scrollRectToVisible(caret, animated: false)
    }
}

// MARK: - UITextViewDelegate

extension MemoTextView: UITextViewDelegate {
    func textViewDidChange(_ textView: UITextView) {
        isHiddenPlaceHolderIfNeeded()
        scrollSelectTextPosition()
        guard let keyboardFrame = keyboardFrame, let duration = keyboardAnimationDuration else { return }
        adjustInsetBottomWillShowKeyboard(keyboardFrame: keyboardFrame, duration: duration)
        scrollSelectTextPosition()
    }

    func textViewDidEndEditing(_ textView: UITextView) {
        textView.makeSepalateLinesFont(firstLineFont: boldFont, otherLinesFont: normalFont)
    }

    func scrollViewDidScrollToTop(_ scrollView: UIScrollView) {
        // コピペ量が多いと反映されていないケースへの対処
        scrollView.layoutIfNeeded()
    }
}

private extension UITextView {
    /// 1行目とそれ以降の文字列、それぞれに対して別々のfontを適用させる（処理の途中でreturnの場合はfontに変更なし）
    ///
    /// - Parameters:
    ///   - firstLineFont: 1行目の文字列に適用するfont
    ///   - otherLinesFont: 2行目以降の文字列に適用するfont
    func makeSepalateLinesFont(firstLineFont: UIFont, otherLinesFont: UIFont) {
        guard let text = text else { return }
        let lines = text.components(separatedBy: .newlines)
        guard !lines.isEmpty else { return }

        let attributeFirstLine = NSMutableAttributedString(string: lines[0], attributes: [.font: firstLineFont])
        let mutableAttributedString = NSMutableAttributedString()
        mutableAttributedString.append(attributeFirstLine)

        let otherLines = lines.enumerated().filter { $0.offset != 0 }.map { $0.element }.joined(separator: "\n")
        // 2行目以降があれば、改行挟んで処理
        if !otherLines.isEmpty {
            let attributeNewLine = NSMutableAttributedString(string: "\n")
            let attributeOtherLines = NSMutableAttributedString(string: otherLines,
                                                                attributes: [.font: otherLinesFont])
            mutableAttributedString.append(attributeNewLine)
            mutableAttributedString.append(attributeOtherLines)
        }

        attributedText = mutableAttributedString
    }
}
