const MAX_NODES: usize = 64;
const NAME: usize = 32;
const MAX_CHILDREN: usize = 16;
const NIL: usize = usize::MAX;

#[derive(Clone, Copy)]
pub struct Node {
    pub name: [u8; NAME],
    pub nlen: usize,
    pub parent: usize,
    pub children: [usize; MAX_CHILDREN],
    pub nchildren: usize,
}

const EMPTY: Node = Node {
    name: [0; NAME],
    nlen: 0,
    parent: NIL,
    children: [NIL; MAX_CHILDREN],
    nchildren: 0,
};

pub struct Fs {
    pub nodes: [Node; MAX_NODES],
    pub count: usize,
    pub cwd: usize,
}

impl Fs {
    pub const fn new() -> Self {
        let mut nodes = [EMPTY; MAX_NODES];
        nodes[0].name[0] = b'/';
        nodes[0].nlen = 1;
        nodes[0].parent = 0;
        Self { nodes, count: 1, cwd: 0 }
    }

    fn child(&self, dir: usize, name: &[u8]) -> Option<usize> {
        let n = &self.nodes[dir];
        for i in 0..n.nchildren {
            let c = n.children[i];
            if self.nodes[c].nlen == name.len() && self.nodes[c].name[..name.len()] == *name {
                return Some(c);
            }
        }
        None
    }

    fn alloc_in(&mut self, parent: usize, name: &[u8]) -> Option<usize> {
        if self.count >= MAX_NODES { return None; }
        if self.nodes[parent].nchildren >= MAX_CHILDREN { return None; }
        if self.child(parent, name).is_some() { return None; }

        let idx = self.count;
        self.count += 1;
        let len = name.len().min(NAME);
        self.nodes[idx].name[..len].copy_from_slice(&name[..len]);
        self.nodes[idx].nlen = len;
        self.nodes[idx].parent = parent;
        self.nodes[idx].nchildren = 0;

        let nc = self.nodes[parent].nchildren;
        self.nodes[parent].children[nc] = idx;
        self.nodes[parent].nchildren += 1;
        Some(idx)
    }

    pub fn mkdir(&mut self, name: &[u8]) -> bool {
        self.alloc_in(self.cwd, name).is_some()
    }

    pub fn mkdir_p(&mut self, path: &[u8]) {
        let (mut cur, mut i) = if path.first() == Some(&b'/') { (0, 1) } else { (self.cwd, 0) };
        let mut seg = i;
        loop {
            let end = i >= path.len();
            if end || path[i] == b'/' {
                let s = &path[seg..i];
                if !s.is_empty() && s != b"." && s != b".." {
                    cur = match self.child(cur, s) {
                        Some(c) => c,
                        None => self.alloc_in(cur, s).unwrap_or(cur),
                    };
                }
                seg = i + 1;
            }
            if end { break; }
            i += 1;
        }
    }

    pub fn cd(&mut self, path: &[u8]) -> bool {
        let (mut cur, mut i) = if path.first() == Some(&b'/') { (0, 1) } else { (self.cwd, 0) };
        let mut seg = i;
        loop {
            let end = i >= path.len();
            if end || path[i] == b'/' {
                let s = &path[seg..i];
                if s == b".." {
                    let p = self.nodes[cur].parent;
                    if p != NIL { cur = p; }
                } else if !s.is_empty() && s != b"." {
                    match self.child(cur, s) {
                        Some(c) => cur = c,
                        None => return false,
                    }
                }
                seg = i + 1;
            }
            if end { break; }
            i += 1;
        }
        self.cwd = cur;
        true
    }

    pub fn print_path(&self) {
        let mut stack = [0usize; 32];
        let mut depth = 0;
        let mut cur = self.cwd;
        while cur != 0 && depth < 32 {
            stack[depth] = cur;
            depth += 1;
            let p = self.nodes[cur].parent;
            if p == cur || p == NIL { break; }
            cur = p;
        }
        if depth == 0 {
            crate::vga::print_str("/");
        } else {
            for i in (0..depth).rev() {
                crate::vga::print_str("/");
                let n = &self.nodes[stack[i]];
                crate::vga::print_bytes(&n.name[..n.nlen]);
            }
        }
    }

    pub fn pwd(&self) {
        self.print_path();
        crate::vga::print_str("\n");
    }

    pub fn ls(&self) {
        let n = &self.nodes[self.cwd];
        if n.nchildren == 0 {
            crate::vga::print_str("(empty)\n");
            return;
        }
        for i in 0..n.nchildren {
            let c = &self.nodes[n.children[i]];
            crate::vga::print_bytes(&c.name[..c.nlen]);
            crate::vga::print_str("/\n");
        }
    }

    pub fn node_count(&self) -> usize { self.count }
}
