/**
 * 领域层（对应原 xfg-frame-domain）—— 整个架构的核心。
 * <p>按业务领域分包（{@code order}、{@code rule}、{@code user}），每个领域包内固定三部分：
 * <ul>
 *   <li>{@code model}   —— 模型对象：{@code aggregate} 聚合 / {@code entity} 实体 / {@code valobj} 值对象；</li>
 *   <li>{@code repository} —— 仓储接口（实现在 infrastructure，依赖倒置）；</li>
 *   <li>{@code service} —— 领域服务：本领域的核心业务规则。</li>
 * </ul>
 * <p>一个领域模型 = 一个充血结构。领域层<b>禁止依赖</b> application / trigger / infrastructure。
 */
package com.example.app.domain;
