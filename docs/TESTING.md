# Testing & CI

## Run unit tests (local)

```bash
./gradlew :app:testDebugUnitTest
```

Reports:

```text
app/build/test-results/testDebugUnitTest/
app/build/reports/tests/testDebugUnitTest/index.html
```

## Current tests

| Class | Covers |
|-------|--------|
| `TextSanitizerTest` | Space → underscore |
| `FileMutatorTest` | Create / rename / delete in a temp folder |
| `FileItemTest` | Data class fields |

---

## How unit tests are made (learn & add your own)

### 1. Where files live

```text
app/src/main/java/com/example/wayer/.../Foo.java     ← production code
app/src/test/java/com/example/wayer/.../FooTest.java ← unit test
```

Mirror the **package** of the class under test.

### 2. Minimal test class

```java
package com.example.wayer.utils;

import org.junit.Test;
import static org.junit.Assert.assertEquals;

public class TextSanitizerTest {
    @Test
    public void replacesSpaces() {
        assertEquals("a_b", TextSanitizer.replaceSpacesWithUnderscores("a b"));
    }
}
```

- `@Test` marks a method as a test.
- `assertEquals` / `assertTrue` / `assertFalse` check results.
- Method names describe the behaviour (`createFileAndDelete`).

### 3. Arrange → Act → Assert

```java
@Test
public void renameFile() {
    // Arrange – set up files / objects
    FileMutator.createFile(tempDir.getAbsolutePath(), "old.txt");

    // Act – call the code under test
    FileMutator.Result r = FileMutator.rename(...);

    // Assert – check outcome
    assertTrue(r.ok);
}
```

### 4. Temp files (`@Before` / `@After`)

For disk tests, create a temp directory before each test and delete it after (see `FileMutatorTest`). That keeps tests isolated.

### 5. What makes a good unit test

- **Fast** – no network, no real device UI.
- **Deterministic** – same result every run.
- **One main behaviour** per test method.
- Prefer testing **pure Java** helpers (`FileMutator`, parsers, sanitizers).

### 6. What not to unit-test here

| Avoid in unit tests | Prefer |
|---------------------|--------|
| JNI / C++ | Device smoke / later native tests |
| Full Fragment UI clicks | Espresso (`androidTest`) |
| Live WayerPC sockets | Manual / integration |

### 7. Adding a test for a new feature

1. Write or change production code.
2. Add `SomethingTest.java` under `src/test/java/...`.
3. Run `./gradlew :app:testDebugUnitTest`.
4. If it fails, fix code or test until green.

---

## Instrumented tests (optional)

```text
app/src/androidTest/java/...
./gradlew :app:connectedDebugAndroidTest
```

Needs a device/emulator. Dependencies are already in `app/build.gradle`.

---

## GitHub Actions

`.github/workflows/android-ci.yml` runs unit tests on push/PR.

---

## Python tool hook

```text
./gradlew :app:testDebugUnitTest
# exit code 0 = pass
```

Then continue to `assembleDebug` / `assembleRelease` (see `docs/RELEASE_AND_BUILD.md`).
