require "thread"

alias old_puts puts

$puts_mutex = Mutex.new

def puts(*args)
    $puts_mutex.synchronize {
        old_puts(*args)
    }
end
