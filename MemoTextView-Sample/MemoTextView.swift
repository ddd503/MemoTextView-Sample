//
//  MemoTextView.swift
//  MemoTextView-Sample
//
//  Created by kawaharadai on 2019/09/03.
//  Copyright © 2019 kawaharadai. All rights reserved.
//

import UIKit

protocol MemoTextViewDelegate: class {
    func textViewDidChange(_ textView: UITextView)
}

@IBDesignable class MemoTextView: UITextView {

    // MARK: - Propaty

    weak var _delegate: MemoTextViewDelegate?
    private lazy var placeHolderLabel = UILabel(frame: CGRect(x: 15, y: 15, width: 0, height: 0))
    private var keyboardFrame: CGRect?
    private var keyboardAnimationDuration: TimeInterval?

    // placeHolderの内容は、Storyboardから編集できるようにする
    @IBInspectable var placeHolderText: String = "" {
        didSet {
            placeHolderLabel.text = placeHolderText
            placeHolderLabel.sizeToFit()
        }
    }

    // MARK: - LifeCycle

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
        isHiddenPlaceHolderIfNeeded()
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow(notification:)), name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide(notification:)), name: UIResponder.keyboardWillHideNotification, object: nil)
    }


    private func addPlaceHolder() {
        placeHolderLabel.font = font
        placeHolderLabel.textColor = .lightGray
        placeHolderLabel.sizeToFit()
        addSubview(placeHolderLabel)
    }

    @objc private func keyboardWillShow(notification: Notification) {
        guard let keyboardFrame = (notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue,
            let duration = notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? TimeInterval else { return }
        self.keyboardFrame = keyboardFrame
        self.keyboardAnimationDuration = duration
        updateTransformIfNeeded(isShowKeyboard: true, keyboardFrame: keyboardFrame, duration: duration)
    }

    @objc private func keyboardWillHide(notification: Notification) {
        guard let duration = notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? TimeInterval else { return }
        updateTransformIfNeeded(isShowKeyboard: false, duration: duration)
    }

    func isHiddenPlaceHolderIfNeeded() {
        placeHolderLabel.isHidden = !text.isEmpty
    }

    /// テキスト量がキーボードで隠れるようならレイアウトを調整する
    func updateTransformIfNeeded(isShowKeyboard: Bool, keyboardFrame: CGRect? = nil, duration: TimeInterval) {
        if isShowKeyboard, let keyboardFrame = keyboardFrame {
            guard isOverKeyboardSize(keyboardFrame.size), transform.isIdentity else { return }
            // 押し上げ分、コンテンツは下げる(スクロール幅を広げる)
            contentInset.top += keyboardFrame.height
            UIView.animate(withDuration: duration, animations: { [weak self] in
                self?.transform = CGAffineTransform(translationX: 0, y: -keyboardFrame.height)
            })
        } else {
            guard !self.transform.isIdentity else { return }
            contentInset.top = 0
            UIView.animate(withDuration: duration, animations: { [weak self] in
                self?.transform = .identity
            })
        }
    }

    /// キーボードが出た時にテキストが隠れるかどうか
    ///
    /// - Parameter size: キーボードのサイズ
    /// - Returns: Bool
    func isOverKeyboardSize(_ size: CGSize) -> Bool {
        let overLimit = UIScreen.main.bounds.height - size.height
        let currentHeight = (UIScreen.main.bounds.height - frame.height) + contentSize.height
        return currentHeight > overLimit
    }

    // キーボード上に閉じるボタンを追加する
    func addCloseButtonOnKeyboard(textView: UITextView, buttonTitle: String? = nil) {
        let backgroundView = UIView(frame: CGRect(x: 0, y: 0,
                                                  width: UIScreen.main.bounds.width, height: 40))
        let buttonWidth = UIScreen.main.bounds.width * 0.2
        let buttonHeight = backgroundView.frame.height
        let closeButton = UIButton(frame: CGRect(x: backgroundView.frame.width - buttonWidth, y: 0,
                                                 width: buttonWidth, height: buttonHeight))
        closeButton.setTitle(buttonTitle ?? "下げる", for: .normal)
        closeButton.titleLabel?.font = textView.font
        closeButton.setTitleColor(UIColor(named: "myBlue")!, for: .normal)
        closeButton.addTarget(self, action: #selector(closeKeyboard(sender:)), for: .touchUpInside)
        backgroundView.addSubview(closeButton)
        textView.inputAccessoryView = backgroundView
    }

    @objc func closeKeyboard(sender: UIButton) {
        endEditing(true)
    }
}

// MARK: - UITextViewDelegate

extension MemoTextView: UITextViewDelegate {
    func textViewDidChange(_ textView: UITextView) {
        isHiddenPlaceHolderIfNeeded()
        _delegate?.textViewDidChange(textView)
        guard let keyboardFrame = keyboardFrame, let duration = keyboardAnimationDuration else { return }
        updateTransformIfNeeded(isShowKeyboard: true, keyboardFrame: keyboardFrame, duration: duration)
    }

    func textViewDidEndEditing(_ textView: UITextView) {
        textView.makeSepalateLinesFont(firstLineFont: UIFont(name: "HiraginoSans-W6", size: 17)!,
                                       otherLinesFont: UIFont(name: "HiraginoSans-W3", size: 17)!)
    }
}

extension UITextView {
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
