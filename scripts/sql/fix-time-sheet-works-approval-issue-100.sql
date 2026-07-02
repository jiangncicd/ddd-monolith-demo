-- issue #100 数据修复：psa_time_sheet_works.approval 为空时按 task → project 链路回填
--
-- 链路：works.task_id → plan_task.id → plan_task.project_id → project.id → project.manager_id
-- 条件：works.task_id IS NOT NULL AND works.approval IS NULL
--
-- ⚠️ 生产执行前 DBA 备份 psa_time_sheet_works

USE [ruoyi-vue-pro];
GO

-- 预览
SELECT COUNT(*) AS affected_count
FROM psa_time_sheet_works w
INNER JOIN psa_pm_plan_task pt ON pt.id = w.task_id
INNER JOIN psa_pm_project    p  ON p.id  = pt.project_id
WHERE w.deleted = '0'
  AND w.task_id IS NOT NULL
  AND w.approval IS NULL
  AND p.manager_id IS NOT NULL;

-- 更新
UPDATE w
SET w.approval    = p.manager_id,
    w.update_time = GETDATE(),
    w.updater     = 'system-fix-issue-100'
FROM psa_time_sheet_works w
INNER JOIN psa_pm_plan_task pt ON pt.id = w.task_id
INNER JOIN psa_pm_project    p  ON p.id  = pt.project_id
WHERE w.deleted = '0'
  AND w.task_id IS NOT NULL
  AND w.approval IS NULL
  AND p.manager_id IS NOT NULL;

PRINT '回填行数: ' + CAST(@@ROWCOUNT AS VARCHAR);
