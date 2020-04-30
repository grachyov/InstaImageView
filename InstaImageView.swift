// Copyright © 2020 Ivan Grachev. All rights reserved.

import UIKit

class InstaImageView: UIImageView {
    
    var isZoomEnabled = true
    
    private weak var overlayView: UIView?
    private weak var zoomingImageView: UIImageView?
    
    private var pinchGestureRecognizer: UIPinchGestureRecognizer!
    private var panGestureRecognizer: UIPanGestureRecognizer!
    
    private var isFinishingZooming = false
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }
    
    override init(image: UIImage?) {
        super.init(image: image)
        setup()
    }
    
    override init(image: UIImage?, highlightedImage: UIImage?) {
        super.init(image: image, highlightedImage: highlightedImage)
        setup()
    }
    
    private func setup() {
        isUserInteractionEnabled = true
        pinchGestureRecognizer = UIPinchGestureRecognizer(target: self, action: #selector(didPinch))
        panGestureRecognizer = UIPanGestureRecognizer(target: self, action: #selector(didPan))
        panGestureRecognizer.minimumNumberOfTouches = 2
        panGestureRecognizer.maximumNumberOfTouches = 2
        panGestureRecognizer.delegate = self
        pinchGestureRecognizer.delegate = self
        
        addGestureRecognizer(pinchGestureRecognizer)
        addGestureRecognizer(panGestureRecognizer)
    }
    
    private var zoomingView: UIImageView? {
        if let zoomingView = zoomingImageView { return zoomingView }
        guard let window = UIApplication.shared.windows.first, image != nil, isZoomEnabled else { return nil }
        
        let frame = convert(bounds, to: window)
        let zoomingImageView = UIImageView(frame: frame)
        zoomingImageView.contentMode = contentMode
        zoomingImageView.image = image
        image = nil
        zoomingImageView.isUserInteractionEnabled = true
        zoomingImageView.isExclusiveTouch = true
        zoomingImageView.addGestureRecognizer(pinchGestureRecognizer)
        zoomingImageView.addGestureRecognizer(panGestureRecognizer)
        self.zoomingImageView = zoomingImageView
        
        let overlay = UIView()
        overlay.backgroundColor = UIColor(white: 0, alpha: 1)
        overlay.alpha = 0.1
        self.overlayView = overlay
        
        window.addSubviewConstrainedToFrame(overlay)
        window.addSubview(zoomingImageView)
        
        return zoomingImageView
    }
    
    private func finishZooming() {
        guard let zoomingView = zoomingView, let window = UIApplication.shared.windows.first, !isFinishingZooming else { return }
        isFinishingZooming = true
        
        UIView.animate(withDuration: 0.25, delay: 0, options: .curveEaseInOut, animations: { [weak self, weak zoomingView, weak window, weak overlayView] in
            guard let imageView = self, let window = window else { return }
            overlayView?.alpha = 0
            zoomingView?.transform = .identity
            
            let imageCenter = CGPoint(x: imageView.frame.width * 0.5, y: imageView.frame.height * 0.5)
            let center = imageView.convert(imageCenter, to: window)
            zoomingView?.center = center
        }) { [weak self] finished in
            if finished { self?.zoomingCompletion() }
        }
    }
    
    private func zoomingCompletion() {
        guard overlayView != nil else { return }
        image = zoomingImageView?.image
        zoomingView?.removeFromSuperview()
        overlayView?.removeFromSuperview()
        addGestureRecognizer(pinchGestureRecognizer)
        addGestureRecognizer(panGestureRecognizer)
        isFinishingZooming = false
    }
    
}

extension InstaImageView: UIGestureRecognizerDelegate {
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return gestureRecognizer === panGestureRecognizer && otherGestureRecognizer === pinchGestureRecognizer ||
            gestureRecognizer === pinchGestureRecognizer && otherGestureRecognizer === panGestureRecognizer
    }
    
    @objc private func didPinch(_ gestureRecognizer: UIPinchGestureRecognizer) {
        guard let zoomingView = zoomingView else { return }
        
        switch gestureRecognizer.state {
        case .began, .changed:
            if gestureRecognizer.scale >= 1, gestureRecognizer.numberOfTouches == 2 {
                let a = gestureRecognizer.location(ofTouch: 0, in: zoomingView)
                let b = gestureRecognizer.location(ofTouch: 1, in: zoomingView)
                let location = CGPoint(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2)
                let currentScale = zoomingView.frame.size.width / zoomingView.bounds.size.width
                let scale = gestureRecognizer.scale
                
                let oldLocation = CGPoint(x: location.x * currentScale, y: location.y * currentScale)
                let newLocation = CGPoint(x: location.x * scale, y: location.y * scale)
                let oldCenter = CGPoint(x: zoomingView.frame.size.width * 0.5, y: zoomingView.frame.size.height * 0.5)
                let newCenter = CGPoint(x: zoomingView.bounds.size.width * scale * 0.5, y: zoomingView.bounds.size.height * scale * 0.5)
                
                let oldSpaceFromCenter = CGPoint(x: oldCenter.x - oldLocation.x, y: oldCenter.y - oldLocation.y)
                let newSpaceFromCenter = CGPoint(x: newCenter.x - newLocation.x, y: newCenter.y - newLocation.y)
                let delta = CGPoint(x: newSpaceFromCenter.x - oldSpaceFromCenter.x, y: newSpaceFromCenter.y - oldSpaceFromCenter.y)
                zoomingView.transform = CGAffineTransform(scaleX: scale, y: scale)
                zoomingView.center = CGPoint(x: zoomingView.center.x + delta.x, y: zoomingView.center.y + delta.y)
                
                let newAlpha = 0.1 + (scale - 1) * 0.7
                overlayView?.alpha = newAlpha > 0.7 ? 0.7 : newAlpha
            }
        case .cancelled, .ended, .failed:
            finishZooming()
        default:
            break
        }
    }
    
    @objc private func didPan(_ gestureRecognizer: UIPanGestureRecognizer) {
        guard let zoomingView = zoomingView else { return }
        
        switch gestureRecognizer.state {
        case .began, .changed:
            let translation = gestureRecognizer.translation(in: zoomingView)
            let currentScale = zoomingView.frame.size.width / zoomingView.bounds.size.width
            zoomingView.center = CGPoint(x: zoomingView.center.x + translation.x * currentScale, y: zoomingView.center.y + translation.y * currentScale)
            gestureRecognizer.setTranslation(.zero, in: zoomingView)
        case .cancelled, .ended, .failed:
            finishZooming()
        default:
            break
        }
    }
}
