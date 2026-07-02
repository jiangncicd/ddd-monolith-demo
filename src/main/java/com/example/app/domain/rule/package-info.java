/**
 * 规则领域：下单准入决策。
 * <p>核心规则在 {@code RuleService}（无需持久化）。复杂时可在本包下拆出
 * {@code engine} + {@code logic} 的过滤器链，参考原文的规则引擎结构。
 */
package com.example.app.domain.rule;
