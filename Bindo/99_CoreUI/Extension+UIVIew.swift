//
//  Extension+UIVIew.swift
//  ToDoList
//
//  Created by Sean Choi on 8/21/25.
//

import Foundation
import UIKit

//MARK: - View Animations
@MainActor
extension UIView {
    enum ShakeAxis { case horizontal, vertical }

    //MARK: - Shake
    /// Shake Animation
    func shake(axis: ShakeAxis = .horizontal,
               amplitude: CGFloat = 6,
               duration: CFTimeInterval = 0.3,
               haptic: UINotificationFeedbackGenerator.FeedbackType? = .error,
               completion: (() -> Void)? = nil) {

        // Prevent Duplicate if currently shaking
        if layer.animation(forKey: "shake") != nil { return }

        // Accessibility: if 'reduce motion' is on, replace with simple feedback
        if UIAccessibility.isReduceMotionEnabled {
            let old = layer.borderColor
            layer.borderWidth = 2
            layer.borderColor = UIColor.systemRed.cgColor
            UIView.animate(withDuration: 0.18, animations: { self.alpha = 0.8 }) { _ in
                UIView.animate(withDuration: 0.18, animations: {
                    self.alpha = 1
                    self.layer.borderWidth = 0
                    self.layer.borderColor = old
                }, completion: { _ in completion?() })
            }
            return
        }

        let keyPath = (axis == .horizontal) ? "transform.translation.x" : "transform.translation.y"
        let a = amplitude

        let anim = CAKeyframeAnimation(keyPath: keyPath)
        anim.values = [0, a, -a, a*0.66, -a*0.66, a*0.33, -a*0.33, 0]
        anim.duration = duration
        anim.isAdditive = true
        anim.timingFunctions = [
            CAMediaTimingFunction(name: .easeInEaseOut),
            CAMediaTimingFunction(name: .easeInEaseOut),
            CAMediaTimingFunction(name: .easeInEaseOut)
        ]

        CATransaction.begin()
        CATransaction.setCompletionBlock(completion)
        layer.add(anim, forKey: "shake")
        CATransaction.commit()

        if let type = haptic {
            let g = UINotificationFeedbackGenerator()
            g.prepare()
            g.notificationOccurred(type)
        }
    }
    // MARK: - Fade

        /// 서서히 나타나기
        func fadeIn(duration: TimeInterval = 0.22, delay: TimeInterval = 0,
                    curve: UIView.AnimationOptions = .curveEaseOut,
                    to alpha: CGFloat = 1) {
            if UIAccessibility.isReduceMotionEnabled {
                self.alpha = alpha
                return
            }
            self.alpha = 0
            UIView.animate(withDuration: duration, delay: delay, options: [curve, .beginFromCurrentState]) {
                self.alpha = alpha
            }
        }

        /// 서서히 사라지기
        func fadeOut(duration: TimeInterval = 0.2, delay: TimeInterval = 0,
                     curve: UIView.AnimationOptions = .curveEaseIn,
                     to alpha: CGFloat = 0) {
            if UIAccessibility.isReduceMotionEnabled {
                self.alpha = alpha
                return
            }
            UIView.animate(withDuration: duration, delay: delay, options: [curve, .beginFromCurrentState]) {
                self.alpha = alpha
            }
        }

        // MARK: - Pop (scale)

        /// 살짝 커지며 등장 (스프링)
        func popIn(duration: TimeInterval = 0.32, damping: CGFloat = 0.78, scale: CGFloat = 1.06) {
            if UIAccessibility.isReduceMotionEnabled {
                self.alpha = 1
                return
            }
            self.alpha = 0
            self.transform = CGAffineTransform(scaleX: 0.96, y: 0.96)
            UIView.animate(withDuration: duration,
                           delay: 0,
                           usingSpringWithDamping: damping,
                           initialSpringVelocity: 0,
                           options: [.curveEaseOut, .beginFromCurrentState]) {
                self.alpha = 1
                self.transform = CGAffineTransform(scaleX: scale, y: scale)
            } completion: { _ in
                UIView.animate(withDuration: 0.12) {
                    self.transform = .identity
                }
            }
        }

        /// 살짝 줄어들며 사라짐
        func popOut(duration: TimeInterval = 0.2, scale: CGFloat = 0.96) {
            if UIAccessibility.isReduceMotionEnabled {
                self.alpha = 0
                return
            }
            UIView.animate(withDuration: duration, delay: 0, options: [.curveEaseIn, .beginFromCurrentState]) {
                self.alpha = 0
                self.transform = CGAffineTransform(scaleX: scale, y: scale)
            } completion: { _ in
                self.transform = .identity
            }
        }

        // MARK: - Slide + Fade

        /// 아래에서 살짝 올라오며 등장
        func slideFadeIn(offsetY: CGFloat = 8, duration: TimeInterval = 0.22) {
            if UIAccessibility.isReduceMotionEnabled {
                self.alpha = 1
                return
            }
            self.alpha = 0
            self.transform = CGAffineTransform(translationX: 0, y: offsetY)
            UIView.animate(withDuration: duration, delay: 0, options: [.curveEaseOut, .beginFromCurrentState]) {
                self.alpha = 1
                self.transform = .identity
            }
        }

        /// 위로 살짝 밀리며 사라짐
        func slideFadeOut(offsetY: CGFloat = -6, duration: TimeInterval = 0.2) {
            if UIAccessibility.isReduceMotionEnabled {
                self.alpha = 0
                return
            }
            UIView.animate(withDuration: duration, delay: 0, options: [.curveEaseIn, .beginFromCurrentState]) {
                self.alpha = 0
                self.transform = CGAffineTransform(translationX: 0, y: offsetY)
            } completion: { _ in
                self.transform = .identity
            }
        }

        // MARK: - Cross dissolve (스냅샷 교체용)
        /// 동일 컨테이너 내에서 old -> new 전환 (살짝 슬라이드 + 페이드)
        /// VC에서 제약 활성화 후 호출해 주세요.
        static func swapInContainer(from old: UIView?, to new: UIView,
                                    in container: UIView,
                                    duration: TimeInterval = 0.22) {
            if UIAccessibility.isReduceMotionEnabled {
                old?.alpha = 0
                new.alpha = 1
                return
            }
            new.alpha = 0
            new.transform = CGAffineTransform(translationX: 0, y: 8)

            // 컨테이너만 터치 잠시 비활성화
            let restoreInteraction = container.isUserInteractionEnabled
            container.isUserInteractionEnabled = false

            UIView.animate(withDuration: duration,
                           delay: 0,
                           options: [.curveEaseOut, .beginFromCurrentState]) {
                new.alpha = 1
                new.transform = .identity
                old?.alpha = 0
                old?.transform = CGAffineTransform(translationX: 0, y: -6)
                container.layoutIfNeeded()
            } completion: { _ in
                old?.alpha = 1
                old?.transform = .identity
                container.isUserInteractionEnabled = restoreInteraction
            }
        }
}
