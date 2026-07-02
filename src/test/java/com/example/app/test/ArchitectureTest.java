package com.example.app.test;

import com.tngtech.archunit.core.domain.JavaClasses;
import com.tngtech.archunit.core.importer.ClassFileImporter;
import com.tngtech.archunit.core.importer.ImportOption;
import com.tngtech.archunit.lang.ArchRule;
import org.junit.jupiter.api.BeforeAll;
import org.junit.jupiter.api.Test;

import static com.tngtech.archunit.lang.syntax.ArchRuleDefinition.noClasses;

/**
 * 架构守卫：单模块里没有 Maven 的物理隔离，就用 ArchUnit 把
 * "分包依赖方向"变成会失败的测试。方向：trigger -> application -> domain <- infrastructure
 */
public class ArchitectureTest {

    private static JavaClasses classes;

    @BeforeAll
    static void importClasses() {
        classes = new ClassFileImporter()
                .withImportOption(new ImportOption.DoNotIncludeTests())
                .importPackages("com.example.app");
    }

    @Test
    public void domain_should_not_depend_on_infrastructure() {
        ArchRule rule = noClasses().that().resideInAPackage("..domain..")
                .should().dependOnClassesThat().resideInAPackage("..infrastructure..");
        rule.check(classes);
    }

    @Test
    public void domain_should_not_depend_on_application() {
        ArchRule rule = noClasses().that().resideInAPackage("..domain..")
                .should().dependOnClassesThat().resideInAPackage("..application..");
        rule.check(classes);
    }

    @Test
    public void domain_should_not_depend_on_trigger() {
        ArchRule rule = noClasses().that().resideInAPackage("..domain..")
                .should().dependOnClassesThat().resideInAPackage("..trigger..");
        rule.check(classes);
    }

    @Test
    public void application_should_not_depend_on_trigger() {
        ArchRule rule = noClasses().that().resideInAPackage("..application..")
                .should().dependOnClassesThat().resideInAPackage("..trigger..");
        rule.check(classes);
    }

    @Test
    public void trigger_should_not_depend_on_infrastructure() {
        ArchRule rule = noClasses().that().resideInAPackage("..trigger..")
                .should().dependOnClassesThat().resideInAPackage("..infrastructure..");
        rule.check(classes);
    }
}
