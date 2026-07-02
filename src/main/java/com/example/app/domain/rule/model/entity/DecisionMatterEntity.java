package com.example.app.domain.rule.model.entity;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

/**
 * 实体：规则决策的入参物料。
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class DecisionMatterEntity {
    private String userId;
    private int age;
    private String gender;
}
