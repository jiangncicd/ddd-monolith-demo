package com.example.app.domain.rule.adapter;

import com.example.app.domain.rule.model.valobj.RiskLevel;

/**
 * 端口（防腐接口）：调用外部风控系统。定义在领域层，实现在 infrastructure（依赖倒置）。
 * <p>
 * 和仓储 {@code IXxxRepository} 是同一套路——仓储是"数据库适配器"，本接口是"外部系统适配器"。
 * 用领域语言表达（返回领域值对象 {@link RiskLevel}），<b>不出现</b> HTTP / SDK / 外部 DTO。
 */
public interface IRiskPort {

    /**
     * 评估用户的风险等级。
     *
     * @return 领域视角的风险等级；外部不可用时由实现决定降级策略。
     */
    RiskLevel evaluate(String userId, int age);
}
