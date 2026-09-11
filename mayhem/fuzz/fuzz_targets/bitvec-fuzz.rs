#![no_main]

use bit_vec::BitVec;
use libfuzzer_sys::fuzz_target;

const CAP_GROWTH: usize = 256;

macro_rules! next_usize {
    ($b:ident) => {
        $b.next().unwrap_or(0) as usize
    };
}

macro_rules! next_u8 {
    ($b:ident) => {
        $b.next().unwrap_or(0)
    };
}

fn do_test(data: &[u8]) {
    let mut v = BitVec::<u32>::new();
    let mut bytes = data.iter().copied();

    while let Some(op) = bytes.next() {
        match op % 16 {
            0 => { v = BitVec::new(); }
            1 => { v = BitVec::with_capacity(next_usize!(bytes)); }
            2 => { v = BitVec::from_bytes(&v.to_bytes()[..]); }
            3 => { v = BitVec::from_elem(next_usize!(bytes) % 64, next_u8!(bytes) < 128); }
            4 => {
                if v.len() < CAP_GROWTH {
                    v.push(next_u8!(bytes) < 128);
                }
            }
            5 => { v.pop(); }
            6 => { v.grow(next_usize!(bytes) % 64 + v.len(), next_u8!(bytes) < 128); }
            7 => { v.truncate(next_usize!(bytes)); }
            8 => { v.set_all(); }
            9 => { v.negate(); }
            10 => {
                let _ = v.count_ones();
                let _ = v.count_zeros();
            }
            11 => { v = BitVec::from_bytes(data); }
            12 => {
                if v.len() < CAP_GROWTH {
                    let mut v2 = BitVec::from_bytes(data);
                    v.append(&mut v2);
                }
            }
            13 => { let _ = v.all(); }
            14 => { let _ = v.any(); }
            15 => { let _ = v.none(); }
            _ => {}
        }
    }
}

fuzz_target!(|data: &[u8]| {
    do_test(data);
});
