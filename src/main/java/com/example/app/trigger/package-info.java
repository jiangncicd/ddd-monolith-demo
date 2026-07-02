/**
 * 触发器 / 适配器层（对应原 xfg-frame-trigger，也叫 adapter）。
 * <p>系统的入口：{@code http}、{@code rpc}、{@code mq}、{@code task} 等触发方式。
 * 只做协议转换（DTO ↔ Command/Result），把业务交给 application 用例，不做编排。
 * <p>依赖方向：{@code trigger → application → domain}。
 */
package com.example.app.trigger;
