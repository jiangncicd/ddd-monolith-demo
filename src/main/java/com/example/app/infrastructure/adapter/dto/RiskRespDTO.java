package com.example.app.infrastructure.adapter.dto;

import lombok.Data;

import java.io.Serializable;

/**
 * 外部风控系统的响应 DTO（它自己的返回格式，与领域 RiskLevel 无关）。
 */
@Data
public class RiskRespDTO implements Serializable {
    /** 外部系统的风险等级字段，例如 "LOW" / "HIGH" */
    private String riskLevel;
    /** 外部风险分，示意用 */
    private int score;
}
