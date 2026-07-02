package com.example.app.infrastructure.adapter.dto;

import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.io.Serializable;

/**
 * 外部风控系统的请求 DTO。外部协议模型只在 infrastructure 出现，不外泄到领域层。
 */
@Data
@NoArgsConstructor
@AllArgsConstructor
public class RiskReqDTO implements Serializable {
    private String userId;
    private int age;
}
