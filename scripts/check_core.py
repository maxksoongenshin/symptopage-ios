#!/usr/bin/env python3
"""Run the XCTest test bodies when Command Line Tools have no XCTest framework."""
from pathlib import Path
import os, re, subprocess, tempfile
root=Path(__file__).resolve().parents[1]
tests=(root/'Tests/CoreTests.swift').read_text().replace('import XCTest','import Foundation').replace('@testable import SymptoCore','')
names=re.findall(r'func (test\w+)\(',tests)
asyncs=set(re.findall(r'func (test\w+)\(\)\s*async',tests))
harness=r'''import Foundation
class XCTestCase {
    var cleanup: [() throws -> Void] = []
    func addTeardownBlock(_ block: @escaping () throws -> Void) { cleanup.append(block) }
    deinit { for block in cleanup { try? block() } }
}
func XCTAssertTrue(_ value: @autoclosure () throws -> Bool, file: StaticString = #file, line: UInt = #line) { do { if try !value() { fatalError("Expected true", file: file, line: line) } } catch { fatalError("Unexpected error: \(error)", file: file, line: line) } }
func XCTAssertFalse(_ value: @autoclosure () throws -> Bool, file: StaticString = #file, line: UInt = #line) { do { if try value() { fatalError("Expected false", file: file, line: line) } } catch { fatalError("Unexpected error: \(error)", file: file, line: line) } }
func XCTAssertEqual<T: Equatable>(_ a: @autoclosure () throws -> T, _ b: @autoclosure () throws -> T, file: StaticString = #file, line: UInt = #line) { do { let lhs = try a(), rhs = try b(); if lhs != rhs { fatalError("Values differ", file: file, line: line) } } catch { fatalError("Unexpected error", file: file, line: line) } }
func XCTAssertNotEqual<T: Equatable>(_ a: T, _ b: T, file: StaticString = #file, line: UInt = #line) { if a == b { fatalError("Expected unequal values", file: file, line: line) } }
func XCTAssertNil<T>(_ value: @autoclosure () throws -> T?, file: StaticString = #file, line: UInt = #line) { do { if try value() != nil { fatalError("Expected nil", file: file, line: line) } } catch { fatalError("Unexpected error", file: file, line: line) } }
func XCTAssertNoThrow<T>(_ value: @autoclosure () throws -> T, file: StaticString = #file, line: UInt = #line) { do { _ = try value() } catch { fatalError("Unexpected error: \(error)", file: file, line: line) } }
func XCTAssertThrowsError<T>(_ value: @autoclosure () throws -> T, file: StaticString = #file, line: UInt = #line) { do { _ = try value() } catch { return }; fatalError("Expected error", file: file, line: line) }
'''
with tempfile.TemporaryDirectory(prefix='symptopage-check-') as folder:
    temp=Path(folder)
    (temp/'Tests.swift').write_text(harness+tests)
    (temp/'Main.swift').write_text('@main struct Runner { static func main() async throws {\n'+ '\n'.join(('try await ' if n in asyncs else 'try ')+'CoreTests().'+n+'(); print("PASS '+n+'")' for n in names) +'\nprint("'+str(len(names))+' core checks passed")\n}}')
    env=dict(os.environ,CLANG_MODULE_CACHE_PATH='/tmp/symptopage-clang-cache',SYMPTOPAGE_ROOT=str(root))
    subprocess.run(['swiftc','-parse-as-library','-suppress-warnings','-module-cache-path','/tmp/symptopage-clang-cache',*map(str,sorted((root/'Core').glob('*.swift'))),str(temp/'Tests.swift'),str(temp/'Main.swift'),'-o',str(temp/'checks')],check=True,env=env)
    subprocess.run([str(temp/'checks')],check=True,env=env)
