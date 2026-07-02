/**
 * 用例编排层 / case 层。
 * <p>包名用 {@code application} 而非 {@code case}——后者是 Java 关键字，不能做包名。
 * <p>职责：把多个领域按"用例"编排到一起，并划定事务边界；<b>只编排，不写领域业务规则</b>。
 * <p>依赖方向：{@code application → domain}（禁止依赖 trigger / infrastructure）。
 */
package com.example.app.application;
