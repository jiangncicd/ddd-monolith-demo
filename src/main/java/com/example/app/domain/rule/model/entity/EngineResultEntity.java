package com.example.app.domain.rule.model.entity;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

/**
 * 实体：规则引擎的决策结果。
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class EngineResultEntity {
    private boolean allow;
    private String code;
    private String info;
}
