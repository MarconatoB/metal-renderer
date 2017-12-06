//
//  MathUtilities.swift
//  metal-renderer
//
//  Created by Bastien Marconato on 05.12.17.
//  Copyright © 2017 Marconato. All rights reserved.
//

import Foundation
import simd

func degreesFromRadians(radians: Double) -> Double {
    return (radians / Double.pi) * 180
}

func radiansFromDegrees(degrees: Double) -> Double {
    return (degrees / 180) * Double.pi
}

struct Vertex {
    var position: vector_float4
    var color: vector_float4
}

struct Uniforms {
    var modelViewProjectionMatrix: matrix_float4x4
}

struct PerInstanceUniforms {
    var modelMatrix: matrix_float4x4
    var normalMatrix: matrix_float3x3
}

func translationMatrix(_ position: float3) -> matrix_float4x4 {
    let X = vector_float4(1, 0, 0, 0)
    let Y = vector_float4(0, 1, 0, 0)
    let Z = vector_float4(0, 0, 1, 0)
    let W = vector_float4(position.x, position.y, position.z, 1)
    return matrix_float4x4(columns:(X, Y, Z, W))
}

func scalingMatrix(_ scale: Float) -> matrix_float4x4 {
    let X = vector_float4(scale, 0, 0, 0)
    let Y = vector_float4(0, scale, 0, 0)
    let Z = vector_float4(0, 0, scale, 0)
    let W = vector_float4(0, 0, 0, 1)
    return matrix_float4x4(columns:(X, Y, Z, W))
}

func rotationMatrix(_ angle: Float, _ axis: vector_float3) -> matrix_float4x4 {
    var X = vector_float4(0, 0, 0, 0)
    X.x = axis.x * axis.x + (1 - axis.x * axis.x) * cos(angle)
    X.y = axis.x * axis.y * (1 - cos(angle)) - axis.z * sin(angle)
    X.z = axis.x * axis.z * (1 - cos(angle)) + axis.y * sin(angle)
    X.w = 0.0
    var Y = vector_float4(0, 0, 0, 0)
    Y.x = axis.x * axis.y * (1 - cos(angle)) + axis.z * sin(angle)
    Y.y = axis.y * axis.y + (1 - axis.y * axis.y) * cos(angle)
    Y.z = axis.y * axis.z * (1 - cos(angle)) - axis.x * sin(angle)
    Y.w = 0.0
    var Z = vector_float4(0, 0, 0, 0)
    Z.x = axis.x * axis.z * (1 - cos(angle)) - axis.y * sin(angle)
    Z.y = axis.y * axis.z * (1 - cos(angle)) + axis.x * sin(angle)
    Z.z = axis.z * axis.z + (1 - axis.z * axis.z) * cos(angle)
    Z.w = 0.0
    let W = vector_float4(0, 0, 0, 1)
    return matrix_float4x4(columns:(X, Y, Z, W))
}

func projectionMatrix(_ near: Float, far: Float, aspect: Float, fovy: Float) -> matrix_float4x4 {
    let scaleY = 1 / tan(fovy * 0.5)
    let scaleX = scaleY / aspect
    let scaleZ = -(far + near) / (far - near)
    let scaleW = -2 * far * near / (far - near)
    let X = vector_float4(scaleX, 0, 0, 0)
    let Y = vector_float4(0, scaleY, 0, 0)
    let Z = vector_float4(0, 0, scaleZ, -1)
    let W = vector_float4(0, 0, scaleW, 0)
    return matrix_float4x4(columns:(X, Y, Z, W))
}

func perspectiveMatrix(fovyRadians: Float, aspect: Float, nearZ: Float, farZ: Float) -> matrix_float4x4 {
    let ys: Float = 1 / tanf(fovyRadians * 0.5)
    let xs: Float = ys / aspect
    let zs: Float = farZ / (nearZ - farZ)
    return matrix_float4x4(vector_float4(xs, 0, 0, 0),
    vector_float4(0, ys, 0, 0),
    vector_float4(0, 0, zs, -1),
    vector_float4(0, 0, zs * nearZ, 0))
}

func normalized(v: vector_float3) -> vector_float3 {
    let r = sqrt((v.x * v.x) + (v.y * v.y) + (v.z * v.z))
    return (v / r)
}

func lookAtMatrix(eyeX: Float, eyeY: Float, eyeZ: Float,
                  centerX: Float, centerY: Float, centerZ: Float,
                  upX: Float, upY: Float, upZ: Float) -> matrix_float4x4
{
    let eye = vector_float3(eyeX, eyeY, eyeZ)
    let center = vector_float3(centerX, centerY, centerZ)
    let up = vector_float3(upX, upY, upZ)
    
    let z = normalize(eye - center)
    let x = normalize(cross(up, z))
    let y = cross(z, x)
    let t = vector_float3(-dot(x, eye), -dot(y, eye), -dot(z, eye))
    
    return matrix_float4x4(float4(x.x, y.x, z.x, 0),
                           float4(x.y, y.y, z.y, 0),
                           float4(x.z, y.z, z.z, 0),
                           float4(t.x, t.y, t.z, 1))
}

func invertTransposeMatrix(m: matrix_float3x3) -> matrix_float3x3 {
    return m.inverse.transpose
}

func upperLeftMatrix3x3(m: matrix_float4x4) -> matrix_float3x3 {
    let x = vector_float3(m.columns.0.x, m.columns.0.y, m.columns.0.z)
    let y = vector_float3(m.columns.1.x, m.columns.1.y, m.columns.1.z)
    let z = vector_float3(m.columns.2.x, m.columns.2.y, m.columns.2.z)
    
    return matrix_float3x3(x, y, z)
}

