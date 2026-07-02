/**
 * 基础设施层（对应原 xfg-frame-infrastructure）。
 * <p>实现领域层定义的仓储接口（依赖倒置的落地点）：{@code dao} 贴库读写、
 * {@code po} 持久化对象、{@code repository} 完成 聚合/VO ↔ PO 的转换。
 * <p>PO / DAO <b>只在本层出现</b>，不外泄到领域层。
 */
package com.example.app.infrastructure;
