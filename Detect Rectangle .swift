//
//  Detect Rectangle .swift
//  
//
//  Created by Ashot Kirakosyan on 05.10.23.
//
import UIKit
import Vision
import CoreGraphics

// create in your project (imageView) and (editImage)
var image: UIImage?
var editedImage: UIImage?

var imageView = UIImageView()
//  MARK: - Detect Rectangle
    
    func detectDocument(image: UIImage?) {
        guard let image = image else { return }
        guard let cgImage = image.cgImage else {
            return
        }
        
        let request = VNDetectRectanglesRequest { request, error in
            if let error = error {
                print("Error detecting rectangles: \(error)")
                return
            }
            
            guard let results = request.results as? [VNRectangleObservation] else {
                return
            }
            
            self.drawDocumentContours(rectangles: results, image: image)
        }
        
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        
        do {
            try handler.perform([request])
        } catch {
            print("Error performing detection: \(error)")
        }
    }
    
//  MARK: Drow Document Contours
    func drawDocumentContours(rectangles: [VNRectangleObservation], image: UIImage) {
        let lineWidth = 0.005 * image.size.width
        let cyrleWidth = lineWidth * 4
        
        // Create a new layer to draw the contours and ellipses
        let drawingLayer = CALayer()
        drawingLayer.frame = CGRect(origin: .zero, size: image.size)
        drawingLayer.contents = image.cgImage
        
        for rectangle in rectangles {
            
            // Calculate corner points
            let topLeft = CGPoint(x: rectangle.topLeft.x * image.size.width, y: (1 - rectangle.topLeft.y) * image.size.height)
            let topRight = CGPoint(x: rectangle.topRight.x * image.size.width, y: (1 - rectangle.topRight.y) * image.size.height)
            let bottomLeft = CGPoint(x: rectangle.bottomLeft.x * image.size.width, y: (1 - rectangle.bottomLeft.y) * image.size.height)
            let bottomRight = CGPoint(x: rectangle.bottomRight.x * image.size.width, y: (1 - rectangle.bottomRight.y) * image.size.height)
            
            // Create a shape layer for the path
            let pathLayer = CAShapeLayer()
            pathLayer.lineWidth = lineWidth
            pathLayer.fillColor = UIColor.clear.cgColor
            pathLayer.strokeColor = UIColor.systemCyan.cgColor
            
            // Create a path connecting ellipses with lines
            let path = UIBezierPath()
            path.move(to: CGPoint(x: topLeft.x, y: topLeft.y))
            path.addLine(to: CGPoint(x: topRight.x, y: topRight.y))
            path.addLine(to: CGPoint(x: bottomRight.x, y: bottomRight.y))
            path.addLine(to: CGPoint(x: bottomLeft.x, y: bottomLeft.y))
            path.close()
            
            pathLayer.path = path.cgPath
            drawingLayer.addSublayer(pathLayer)
            
            // Helper function to create ellipse layers
            func createEllipseLayer(center: CGPoint) -> CAShapeLayer {
                let ellipsePath = UIBezierPath(ovalIn: CGRect(x: center.x - cyrleWidth / 2, y: center.y - cyrleWidth / 2, width: cyrleWidth, height: cyrleWidth))
                let ellipseLayer = CAShapeLayer()
                ellipseLayer.path = ellipsePath.cgPath
                ellipseLayer.strokeColor = UIColor.systemCyan.cgColor
                ellipseLayer.lineWidth = lineWidth
                ellipseLayer.fillColor = UIColor.white.cgColor
                
                return ellipseLayer
            }
            
            // Create and add ellipse layers
            drawingLayer.addSublayer(createEllipseLayer(center: topLeft))
            drawingLayer.addSublayer(createEllipseLayer(center: topRight))
            drawingLayer.addSublayer(createEllipseLayer(center: bottomLeft))
            drawingLayer.addSublayer(createEllipseLayer(center: bottomRight))
        }
        
        // Convert the layer to an image
        UIGraphicsBeginImageContextWithOptions(image.size, false, 0.0)
        if let context = UIGraphicsGetCurrentContext() {
            drawingLayer.render(in: context)
            let drawnImage = UIGraphicsGetImageFromCurrentImageContext()
            UIGraphicsEndImageContext()
            
            DispatchQueue.main.async {
                self.editedImage = drawnImage
                self.imageView.image = self.editedImage
            }
        }
    }
 
//  MARK: - Crop And Fix Perspective image
    func cropAndAlignImage(image: UIImage?, sender: UIButton) {
        guard let image = image, let cgImage = image.cgImage else {
            return
        }
        
        let request = VNDetectRectanglesRequest { request, error in
            if let error = error {
                print("Error detecting rectangles: \(error)")
                return
            }
            
            guard let results = request.results as? [VNRectangleObservation] else {
                return
            }
            
            for rectangle in results {
                
                //                self.editedImage = image.flattened
                self.editedImage = self.flattenImage(using: rectangle, in: image)
                DispatchQueue.main.async {
                    if sender.isSelected {
                        self.imageView.image = self.editedImage
                    } else {
                        self.imageView.image = image
                        self.detectDocument(image: self.imageView.image)
                    }
                }
            }
        }
        
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        
        do {
            try handler.perform([request])
        } catch {
            print("Error performing detection: \(error)")
        }
    }
    
    func flattenImage(using observation: VNRectangleObservation, in image: UIImage) -> UIImage? {
        guard let ciImage = CIImage(image: image) else {
            return nil
        }
        
        let topLeft = observation.topLeft.scaled(to: ciImage.extent.size)
        let topRight = observation.topRight.scaled(to: ciImage.extent.size)
        let bottomLeft = observation.bottomLeft.scaled(to: ciImage.extent.size)
        let bottomRight = observation.bottomRight.scaled(to: ciImage.extent.size)
        
        let correctedImage = ciImage.applyingFilter("CIPerspectiveCorrection", parameters: [
            "inputTopLeft": CIVector(cgPoint: topLeft),
            "inputTopRight": CIVector(cgPoint: topRight),
            "inputBottomLeft": CIVector(cgPoint: bottomLeft),
            "inputBottomRight": CIVector(cgPoint: bottomRight)
        ])
        
        if let cgImage = CIContext().createCGImage(correctedImage, from: correctedImage.extent) {
            return UIImage(cgImage: cgImage, scale: image.scale, orientation: image.imageOrientation)
        }
        
        return nil
    }
