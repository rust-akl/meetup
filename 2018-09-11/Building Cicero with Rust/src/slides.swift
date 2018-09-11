import TruffautSupport


let structure = """
Cicero iOS
├── User Interface
│   └── Swift/ObjC (Apple Cocoa Touch)
└── Unicode Database
    └── libucd
        ├── C Headers
        ├── Unsafe and no_mangle Rust
        ├── Unicode Data
        │   └── Rust (open-i18n/rust-unic)
        └── Full-Text Search
            └── Rust (jgallagher/rusqlite)
"""

let no_mangle_example = """
#[no_mangle]
pub extern fn UCDGetUnicodeVersion(out_major: *mut u16,
                                   out_minor: *mut u16,
                                   out_micro: *mut u16) {
    unsafe {
        *out_major = UNICODE_VERSION.major;
        *out_minor = UNICODE_VERSION.minor;
        *out_micro = UNICODE_VERSION.micro;
    }
}
"""

let c_header_example = """
UCD_EXPORT
void
UCDGetUnicodeVersion(uint16_t * outMajor,
                     uint16_t * outMinor,
                     uint16_t * outMicro);
"""

let swift_interface = """
public func UCDGetUnicodeVersion(_ outMajor: UnsafeMutablePointer<UInt16>,
                                 _ outMinor: UnsafeMutablePointer<UInt16>,
                                 _ outMicro: UnsafeMutablePointer<UInt16>)
"""

let swift_call = """
var major: UInt16 = 0
var minor: UInt16 = 0
var micro: UInt16 = 0
UCDGetUnicodeVersion(&major, &minor, &micro)
"""

let rust_struct = """
#[derive(Clone)]
pub struct UCDGraphemeCluster {
    character: String,
    scalars: Vec<UCDScalar>,
}
"""

let copy_struct = """
#[no_mangle]
pub extern fn UCDStringCopyGraphemeClusterAtIndex(
    string: *const UCDString,
    index: size_t) -> *mut UCDGraphemeCluster {

    let ucd_string = unsafe { &*string };
    let grapheme_cluster = ucd_string.grapheme_clusters[index].clone();
    Box::into_raw(Box::new(grapheme_cluster))
}
"""

let release_struct = """
#[no_mangle]
pub extern fn UCDGraphemeClusterRelease(
    grapheme_cluster: *mut UCDGraphemeCluster) {

    unsafe {
        Box::from_raw(grapheme_cluster);
    }
}
"""

let use_struct = """
let graphemeCluster = UCDStringCopyGraphemeClusterAtIndex(ucdString, index)
// do something with graphemeCluster
UCDGraphemeClusterRelease(graphemeCluster)
"""

let ucd_bug_h = """
UCD_EXPORT UCDStringRef UCDStringCreateWithCString(
    const char * cString);
"""

let ucd_bug = """
#[no_mangle]
pub extern fn UCDStringCreateWithCString(
    string: *const c_char) -> *mut UCDString {

    let c_str = unsafe { CStr::from_ptr(string) };
    let input = c_str.to_str().unwrap();
    // ...
}
"""

let ucd_fix = """
#[no_mangle]
pub extern fn UCDStringCreateWithUTF8Bytes(
    bytes: *mut u8,
    bytes_len: size_t) -> *mut UCDString {

    let input = unsafe {
        String::from_raw_parts(bytes, bytes_len, bytes_len)
    };
    // ...
}
"""

let rust_saved_me = """
let transaction = database.connection.transaction();
// continue to use database to do stuff
"""

let compiler_error = """
error[E0507]: cannot move out of borrowed content
  --> src/search.rs:59:5
   |
59 |     ucd_database.connection;
   |     ^^^^^^^^^^^^ cannot move out of borrowed content
"""


let presentation = Presentation(pages: [

    Page(title: "Building Cicero with Rust"),

    Page(title: "Cicero: A Unicode® Tool", subtitle: "A simple iOS app for checking Unicode Character Database (UCD)"),

    Page(title: "More About Cicero", contents: [
        .text("Cicero is my personal project"),
        .text("It was released on June, 2018"),
        .text("Some of users are from Apple and The Unicode Consortium"),
        .text("My first time to use Rust in a real project"),
        .text("Rust because libicu is too hard to use"),
    ]),

    Page(title: "Demo", subtitle: "Let's take a look at the app"),

    Page(title: "Languages & Libraries Used", contents: [
        .sourceCode(.plainText, structure),
    ]),

    Page(title: "Building A Static Library for iOS with Rust", contents: [
        .text("ARMv7/ARMv7s/ARM64 (iOS Devices)"),
        .text("i386/x86_64 (iOS Simulators)"),
        .text("Debug/Release build configs"),
        .text(""),
        .text("A cargo subcommand that makes these a lot easier to work with:"),
        .indent([
            .sourceCode(.plainText, "TimNN/cargo-lipo"),
        ]),
    ]),

    Page(title: "Calling the Rust Library from Swift/ObjC", contents: [
        .text("Rust ABI is not stable"),
        .text("Rust has good C FFI"),
        .text("Swift/ObjC has good interoperability with C"),
        .text("Use a C header and an unsafe no_mangled Rust layer to bridge the core and the UI"),
        .sourceCode(.plainText, "unicode_version.rs"),
        .indent([
            .sourceCode(.rust, "pub const UNICODE_VERSION: UnicodeVersion = ...;"),
        ]),
        .sourceCode(.plainText, "ucd.rs"),
        .indent([
            .sourceCode(.rust, no_mangle_example),
        ]),
        .sourceCode(.plainText, "nm libucd.a | rg UCDGetUnicodeVersion"),
        .indent([
            .sourceCode(.plainText, "0000000000000050 T _UCDGetUnicodeVersion"),
        ]),
        .sourceCode(.plainText, "libucd.h"),
        .indent([
            .sourceCode(.c, c_header_example),
        ]),
        .sourceCode(.plainText, "Swift Interface Generated by swiftc"),
        .indent([
            .sourceCode(.swift, swift_interface),
        ]),
        .sourceCode(.plainText, "UnicodeData.swift"),
        .indent([
            .sourceCode(.swift, swift_call),
        ]),
    ]),

    Page(title: "Passing Around Objects", contents: [
        .text("Passing around a Rust struct to Swift/ObjC"),
        .indent([
            .sourceCode(.rust, rust_struct),
        ]),
        .text("It's hard to map the internals of the Rust struct into a C struct"),
        .text("Opaque pointer"),
        .indent([
            .sourceCode(.c, "typedef struct UCDGraphemeCluster * UCDGraphemeClusterRef;"),
        ]),
        .text("Clone the struct and by-pass the Rust memory management"),
        .text("Pass around the opaque pointer instead"),
        .indent([
            .sourceCode(.rust, copy_struct),
        ]),
        .text("When finished with the opaque pointer, pass it back to deallocate the memory"),
        .indent([
            .sourceCode(.rust, release_struct),
        ]),
        .text("This mimics the CoreFoundation naming convention when used in Swift"),
        .indent([
            .text("If you use a Get function, you cannot be certain of the returned object’s life span"),
            .text("If you use a Copy or Create function, you are responsible for releasing the object"),
        ]),
        .indent([
            .sourceCode(.swift, use_struct),
        ]),
    ]),

    Page(title: "Debugging the Rust Library", contents: [
        .text("One day a test user reported:"),
        .indent([
            .text("Characters are ignored after U+0000"),
            .text("\"A,U+0000,B\" -> \"A\"")
        ]),
        .text("Debugging the UI code observed the string was correctly passed from the UI"),
        .text("The related Rust API in libucd:"),
        .indent([
            .sourceCode(.plainText, "libucd.h"),
            .indent([
                .sourceCode(.c, ucd_bug_h),
            ]),
            .sourceCode(.plainText, "ucd.rs"),
            .indent([
                .sourceCode(.rust, ucd_bug),
            ]),
        ]),
        .text("U+0000 -> 0x0 -> The Null Terminator '\\0'"),
        .text("Use a counted byte buffer instead of a C string fixed it"),
        .indent([
            .sourceCode(.plainText, "ucd.rs"),
            .indent([
                .sourceCode(.rust, ucd_fix),
            ]),
        ]),
    ]),

    Page(title: "Debugging libucd in Xcode", contents: [
        .image("images/debugging-1.png"),
        .image("images/debugging-2.png"),
        .image("images/fixed.png"),
    ]),

    Page(title: "Rust Saved Me", contents: [
        .sourceCode(.rust, rust_saved_me),
    ]),

    Page(title: "Rust Saved Me", contents: [
        .sourceCode(.plainText, compiler_error),
    ]),

    // Need it, Build it, Merge it
    Page(title: "Need it -> Build it -> Share it", contents: [
        .text("Lots and lots of awesome crates"),
        .indent([
            .text("Well designed"),
            .text("Well implemented"),
            .text("Well documented"),
        ]),
        .text("The community is young"),
        .text("You might have to do it by yourself"),
        .text("Don't be shy to contribute"),
        .sourceCode(.plainText, "open-i18n/rust-unic"),
        .indent([
            .sourceCode(.plainText, "unic/ucd/name"),
            .sourceCode(.plainText, "unic/ucd/hangul"),
            .sourceCode(.plainText, "unic/ucd/unihan"),
            .sourceCode(.plainText, "unic/ucd/block"),
            .sourceCode(.plainText, "Unicode 11.0"),
        ]),
    ]),

    Page(title: "Apps with a Native Look & Feel and a Rust Core", contents: [
        .text("google/xi-editor"),
        .text("ImageOptim/gifski"),
        .text("Codezerker/Cicero"),
        .text(""),
        .text("Platform native look & feel usually creates a superior UX"),
        .text("Reuse low-level logics across all platforms"),
        .text("Cargo build system ❤️")
    ]),

    Page(title: "Future Plans for Cicero", contents: [
        .text("fdehau/tui-rs + libucd = Cicero for Command Line"),
        .text("Cocoa + libucd = Cicero for macOS"),
        .text("UWP + libucd = Cicero for Windows"),
    ]),

    Page(title: "Thank you!"),
])
