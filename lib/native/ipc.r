#passthru #include <unistd.h>
#passthru #include <sys/ipc.h>
#passthru #include <sys/shm.h>
#passthru #include <sys/sem.h>
#passthru #include <sys/msg.h>
#passthru #include <sys/types.h>

typedef union {
    int val;
    struct semid_ds *buf;
    unsigned short int *array;
    struct seminfo *__buf;    
} semun;

typedef struct {
    int data_id;
    int data_size;
    int sem_id;
} shm_top;

typedef struct {
    int msg_id;
    int snd_sem_id;
    int rcv_sem_id;
} msg_top;

typedef struct {
    long mtype;
    union {
        char mtext[1];
        int size;
    } u;
} msghead;

typedef struct {
    long mtype;
    char mtext[1024];
} msgblock;

typedef struct {
    int pid;
    int type;
    int id;
} resource;

static void aborted(char *s);
static void cleanup(void);
static void handler(int signo);
static void add_resource(int id, int type);
static void remove_resource(int id, int type);
static int msgsnd_ex(int msqid, void *msgp, size_t msgsz, int msgflg);
static ssize_t msgrcv_ex(int msqid, void *msgp, size_t msgsz, long msgtyp, int msgflg);
static int semop_ex(int semid, struct sembuf *sops, size_t nsops);

#define MAX_RESOURCES 500

static resource resources[MAX_RESOURCES];
static int num_resources = 0;

static struct sdescrip idf = {2, "id"};

#begdef GetSelfId()
int self_id;
dptr self_id_dptr;
static struct inline_field_cache self_id_ic;
self_id_dptr = c_get_instance_data(&self, (dptr)&idf, &self_id_ic);
if (!self_id_dptr)
    syserr("Missing id field");
self_id = IntVal(*self_id_dptr);
if (self_id < 0)
    runerr(219, self);
#enddef

function{0,1} ipc_Shm_open_public_impl(key)
   if !cnv:C_integer(key) then
       runerr(101, key)
   body {
       int top_id;
       top_id = shmget(key, sizeof(shm_top), 0600);
       if (top_id == -1) {
           /* ENOENT causes failure; all other errors abort. */
           if (errno == ENOENT) {
               errno2why();
               fail;
           }
           aborted("Couldn't get shm id");
       }
       return C_integer top_id;
   }
end

function{0,1} ipc_Shm_create_public_impl(key, str)
   if !cnv:C_integer(key) then
       runerr(101, key)
   if !cnv:string(str) then
       runerr(103, str)
   body {
       int top_id, sem_id, data_id;
       shm_top *tp;
       semun arg;
       void *p, *data;
       int size;

       top_id = shmget(key, sizeof(shm_top), IPC_EXCL | IPC_CREAT | 0600);
       if (top_id == -1) {
           /* EEXIST causes failure; all other errors abort. */
           if (errno == EEXIST) {
               errno2why();
               fail;
           }
           aborted("Couldn't get shm id");
       }
       data = StrLoc(str);
       size = StrLen(str);

       tp = (shm_top*)shmat(top_id, 0, 0);
       if ((void*)tp == (void*)-1)
           aborted("Couldn't attach to shm");

       /* Create and initialize the semaphore */
       sem_id = semget(IPC_PRIVATE, 1, IPC_CREAT | 0600);
       if (sem_id == -1)
           aborted("Couldn't get sem id");
       arg.val = 1;
       if (semctl(sem_id, 0, SETVAL, arg) == -1)
           aborted("Couldn't do semctl");

       /* Initialize the data */
       data_id = shmget(IPC_PRIVATE, size, IPC_CREAT | 0600);
       if (data_id == -1)
           aborted("Couldn't get shm id");
       p = shmat(data_id, 0, 0);
       if ((void*)p == (void*)-1)
           aborted("Couldn't attach to shm");
       memcpy(p, data, size);
       shmdt(p);

       tp->sem_id = sem_id;
       tp->data_id = data_id;
       tp->data_size = size;

       shmdt(tp);

       return C_integer top_id;
   }
end

function{0,1} ipc_Shm_create_private_impl(str)
   if !cnv:string(str) then
       runerr(103, str)
   body {
       int top_id, sem_id, data_id;
       shm_top *tp;
       semun arg;
       void *p, *data;
       int size;

       data = StrLoc(str);
       size = StrLen(str);

       top_id = shmget(IPC_PRIVATE, sizeof(shm_top), IPC_CREAT | 0600);
       if (top_id == -1)
           aborted("Couldn't get shm id");

       tp = (shm_top*)shmat(top_id, 0, 0);
       if ((void*)tp == (void*)-1)
           aborted("Couldn't attach to shm");

       /* Create and initialize the semaphore */
       sem_id = semget(IPC_PRIVATE, 1, IPC_CREAT | 0600);
       if (sem_id == -1)
           aborted("Couldn't get sem id");
       arg.val = 1;
       if (semctl(sem_id, 0, SETVAL, arg) == -1)
           aborted("Couldn't do semctl");

       /* Initialize the data */
       data_id = shmget(IPC_PRIVATE, size, IPC_CREAT | 0600);
       if (data_id == -1)
           aborted("Couldn't get shm id");
       p = shmat(data_id, 0, 0);
       if ((void*)p == (void*)-1)
           aborted("Couldn't attach to shm");
       memcpy(p, data, size);
       shmdt(p);

       tp->sem_id = sem_id;
       tp->data_id = data_id;
       tp->data_size = size;

       shmdt(tp);
       add_resource(top_id, 0);

       return C_integer top_id;
   }
end

function{0} ipc_Shm_remove(self)
    body {
       shm_top *tp;
       GetSelfId();

       tp = (shm_top*)shmat(self_id, 0, 0);
       if ((void*)tp == (void*)-1)
           aborted("Couldn't attach to shm");

       shmctl(tp->data_id, IPC_RMID, 0);
       semctl(tp->sem_id, -1, IPC_RMID, 0);
       shmctl(self_id, IPC_RMID, 0);
       shmdt(tp);
       remove_resource(self_id, 0);

       *self_id_dptr = minusonedesc;

       return nulldesc;
   }
end

function{1} ipc_Shm_set_value_impl(self, str)
   if !cnv:string(str) then
       runerr(103, str)
   body {
       shm_top *tp;
       char *data;
       int size;
       struct sembuf p_buf;
       struct shmid_ds shminfo;
       GetSelfId();

       tp = (shm_top*)shmat(self_id, 0, 0);
       if ((void*)tp == (void*)-1)
           aborted("Couldn't attach to shm");
       data = StrLoc(str);
       size = StrLen(str);

       /* Wait */
       p_buf.sem_num = 0;
       p_buf.sem_op = -1;
       p_buf.sem_flg = SEM_UNDO;
       if (semop_ex(tp->sem_id, &p_buf, 1) == -1)
           aborted("wait failed");

       shmctl(tp->data_id, IPC_STAT, &shminfo);
       if (size <= shminfo.shm_segsz) {
           /* New data will fit in current space */
           void *p;
           tp->data_size = size;
           p = shmat(tp->data_id, 0, 0);
           if ((void*)p == (void*)-1)
               aborted("Couldn't attach to shm");
           memcpy(p, data, size);
           shmdt(p);
       } else {
           /* Size too small, get rid of old and reallocate. */
           int data_id;
           void *p;
           shmctl(tp->data_id, IPC_RMID, 0);
           /* Allocate new data and copy */
           data_id = shmget(IPC_PRIVATE, size, IPC_CREAT | 0600);
           if (data_id == -1)
               aborted("Couldn't get shm id");
           p = shmat(data_id, 0, 0);
           if ((void*)p == (void*)-1)
               aborted("Couldn't attach to shm");
           memcpy(p, data, size);
           shmdt(p);

           tp->data_id = data_id;
           tp->data_size = size;
       }
   
       /* Signal */
       p_buf.sem_op = 1;
       if (semop_ex(tp->sem_id, &p_buf, 1) == -1)
           aborted("signal failed");
   
       shmdt(tp);

       return nulldesc;
   }
end

function{1} ipc_Shm_get_value_impl(self)
    body {
       shm_top *tp;
       char *data;
       struct sembuf p_buf;
       GetSelfId();

       tp = (shm_top*)shmat(self_id, 0, 0);
       if ((void*)tp == (void*)-1)
           aborted("Couldn't attach to shm");

       /* Wait */
       p_buf.sem_num = 0;
       p_buf.sem_op = -1;
       p_buf.sem_flg = SEM_UNDO;
       if (semop_ex(tp->sem_id, &p_buf, 1) == -1)
           aborted("wait failed");

       data = (char*)shmat(tp->data_id, 0, 0);
       if ((void*)data == (void*)-1)
           aborted("Couldn't attach to shm");

       bytes2string(data, tp->data_size, &result);
       shmdt(data);

       /* Signal */
       p_buf.sem_op = 1;
       if (semop_ex(tp->sem_id, &p_buf, 1) == -1)
           aborted("signal failed");

       shmdt(tp);

       return result;
   }
end

function{0,1} ipc_Sem_open_public_impl(key)
   if !cnv:C_integer(key) then
       runerr(101, key)
   body {
       int sem_id;
       sem_id = semget(key, 0, 0600);
       if (sem_id == -1) {
           /* ENOENT causes failure; all other errors abort. */
           if (errno == ENOENT) {
               errno2why();
               fail;
           }
           aborted("Couldn't get sem id");
       }
       return C_integer sem_id;
   }
end

function{0,1} ipc_Sem_create_public_impl(key, val)
   if !cnv:C_integer(key) then
       runerr(101, key)
   if !cnv:C_integer(val) then
       runerr(101, val)
   body {
       int sem_id;
       semun arg;
       arg.val = val;

       sem_id = semget(key, 1, IPC_EXCL | IPC_CREAT | 0600);
       if (sem_id == -1) {
           /* EEXIST causes failure; all other errors abort. */
           if (errno == EEXIST) {
               errno2why();
               fail;
           }
           aborted("Couldn't get sem id");
       }

       /* Set the initial value */
       if (semctl(sem_id, 0, SETVAL, arg) == -1)
           aborted("Couldn't do semctl");

       return C_integer sem_id;
   }
end

function{0,1} ipc_Sem_create_private_impl(val)
   if !cnv:C_integer(val) then
       runerr(101, val)
   body {
       int sem_id;
       semun arg;
       arg.val = val;

       sem_id = semget(IPC_PRIVATE, 1, IPC_CREAT | 0600);
       if (sem_id == -1)
           aborted("Couldn't get sem id");

       add_resource(sem_id, 1);

       /* Set the initial value */
       if (semctl(sem_id, 0, SETVAL, arg) == -1)
           aborted("Couldn't do semctl");

       return C_integer sem_id;
   }
end

function{1} ipc_Sem_set_value(self, val)
   if !cnv:C_integer(val) then
       runerr(101, val)
   body {
       semun arg;
       GetSelfId();

       arg.val = val;
       if (semctl(self_id, 0, SETVAL, arg) == -1)
           aborted("Couldn't do semctl");
       return nulldesc;
   }
end

function{1} ipc_Sem_get_value(self)
   body {
       int ret;
       semun arg;
       GetSelfId();

       ret = semctl(self_id, 0, GETVAL, arg);
       if (ret == -1)
           aborted("Couldn't do semctl");
       return C_integer ret;
   }
end

function{1} ipc_Sem_semop(self, n)
   if !cnv:C_integer(n) then
       runerr(101, n)
   body {
       struct sembuf p_buf;
       GetSelfId();
       p_buf.sem_num = 0;
       p_buf.sem_op = n;
       p_buf.sem_flg = SEM_UNDO;
       if (semop_ex(self_id, &p_buf, 1) == -1)
           aborted("semop failed");
       return nulldesc;
   }
end

function{1} ipc_Sem_semop_nowait(self, n)
   if !cnv:C_integer(n) then
       runerr(101, n)
   body {
       struct sembuf p_buf;
       GetSelfId();
       p_buf.sem_num = 0;
       p_buf.sem_op = n;
       p_buf.sem_flg = SEM_UNDO | IPC_NOWAIT;
       if (semop_ex(self_id, &p_buf, 1) == -1) {
           if (errno == EAGAIN) {
               /* Okay, it's not ready,so fail */
               errno2why();
               fail;
           }
           /* A runtime error. */
           aborted("semop failed");
       }
       return nulldesc;
   }
end

function{1} ipc_Sem_remove(self)
   body {
       GetSelfId();
       semctl(self_id, -1, IPC_RMID, 0);
       remove_resource(self_id, 1);
       *self_id_dptr = minusonedesc;
       return nulldesc;
   }
end

function{0,1} ipc_Msg_open_public_impl(key)
   if !cnv:C_integer(key) then
       runerr(101, key)
   body {
       int top_id;
       top_id = shmget(key, sizeof(msg_top), 0600);
       if (top_id == -1) {
           /* ENOENT causes failure; all other errors abort. */
           if (errno == ENOENT) {
               errno2why();
               fail;
           }
           aborted("Couldn't get top id");
       }
       return C_integer top_id;
   }
end

function{0,1} ipc_Msg_create_public_impl(key)
   if !cnv:C_integer(key) then
       runerr(101, key)
   body {
       int top_id, msg_id, rcv_sem_id, snd_sem_id;
       msg_top *tp;
       semun arg;
       top_id = shmget(key, sizeof(msg_top), IPC_EXCL | IPC_CREAT | 0600);
       if (top_id == -1) {
           /* EEXIST causes failure; all other errors abort. */
           if (errno == EEXIST) {
               errno2why();
               fail;
           }
           aborted("Couldn't get shm id");
       }

       tp = (msg_top*)shmat(top_id, 0, 0);
       if ((void*)tp == (void*)-1)
           aborted("Couldn't attach to shm");

       msg_id = msgget(IPC_PRIVATE, IPC_CREAT | 0600);
       if (msg_id == -1)
           aborted("Couldn't get msg id");

       /* Create and initialize the semaphores */
       rcv_sem_id = semget(IPC_PRIVATE, 1, IPC_CREAT | 0600);
       if (rcv_sem_id == -1)
           aborted("Couldn't get sem id");
       arg.val = 1;
       if (semctl(rcv_sem_id, 0, SETVAL, arg) == -1)
           aborted("Couldn't do semctl");
       snd_sem_id = semget(IPC_PRIVATE, 1, IPC_CREAT | 0600);
       if (snd_sem_id == -1)
           aborted("Couldn't get sem id");
       arg.val = 1;
       if (semctl(snd_sem_id, 0, SETVAL, arg) == -1)
           aborted("Couldn't do semctl");

       /* Initialize the top data */
       tp->msg_id = msg_id;
       tp->snd_sem_id = snd_sem_id;
       tp->rcv_sem_id = rcv_sem_id;
       shmdt(tp);

       return C_integer top_id;
   }
end

function{1} ipc_Msg_create_private_impl()
   body {
      int top_id, msg_id, rcv_sem_id, snd_sem_id;
      msg_top *tp;
      semun arg;

      top_id = shmget(IPC_PRIVATE, sizeof(msg_top), IPC_CREAT | 0600);
      if (top_id == -1)
          aborted("Couldn't get shm id");
      tp = (msg_top*)shmat(top_id, 0, 0);
      if ((void*)tp == (void*)-1)
          aborted("Couldn't attach to shm");

      msg_id = msgget(IPC_PRIVATE, IPC_CREAT | 0600);
      if (msg_id == -1)
          aborted("Couldn't get msg id");

      /* Create and initialize the semaphores */
      rcv_sem_id = semget(IPC_PRIVATE, 1, IPC_CREAT | 0600);
      if (rcv_sem_id == -1)
          aborted("Couldn't get sem id");
      arg.val = 1;
      if (semctl(rcv_sem_id, 0, SETVAL, arg) == -1)
          aborted("Couldn't do semctl");
      snd_sem_id = semget(IPC_PRIVATE, 1, IPC_CREAT | 0600);
      if (snd_sem_id == -1)
          aborted("Couldn't get sem id");
      arg.val = 1;
      if (semctl(snd_sem_id, 0, SETVAL, arg) == -1)
          aborted("Couldn't do semctl");

      /* Initialize the top data */
      tp->msg_id = msg_id;
      tp->snd_sem_id = snd_sem_id;
      tp->rcv_sem_id = rcv_sem_id;
      shmdt(tp);

      add_resource(top_id, 2);

       return C_integer top_id;
   }
end

function{1} ipc_Msg_remove(self)
    body {
        msg_top *tp;
        GetSelfId();

        tp = (msg_top*)shmat(self_id, 0, 0);
        if ((void*)tp == (void*)-1)
            aborted("Couldn't attach to shm");

        semctl(tp->rcv_sem_id, -1, IPC_RMID, 0);
        semctl(tp->snd_sem_id, -1, IPC_RMID, 0);
        msgctl(tp->msg_id, IPC_RMID, 0);
        shmctl(self_id, IPC_RMID, 0);
        shmdt(tp);
        remove_resource(self_id, 2);
        *self_id_dptr = minusonedesc;

        return nulldesc;
   }
end

function{1} ipc_Msg_send_impl(self, str)
   if !cnv:string(str) then
       runerr(103, str)
   body {
       msg_top *tp;
       char *data;
       msghead mh;
       msgblock mb;
       struct sembuf p_buf;
       int size, blocks, i, residue;
       GetSelfId();

       tp = (msg_top*)shmat(self_id, 0, 0);
       if ((void*)tp == (void*)-1)
           aborted("Couldn't attach to shm");

       data = StrLoc(str);
       size = StrLen(str);

       /* Wait on send semaphore */
       p_buf.sem_num = 0;
       p_buf.sem_op = -1;
       p_buf.sem_flg = SEM_UNDO;
       if (semop_ex(tp->snd_sem_id, &p_buf, 1) == -1)
           aborted("wait failed");

       mh.u.size = size;
       mh.mtype = 1;
       if (msgsnd_ex(tp->msg_id, &mh, sizeof(mh.u), 0) == -1)
           aborted("Failed to do header msgsnd");

       blocks = size / sizeof(mb.mtext);
       mb.mtype = 1;
       for (i = 0; i < blocks; ++i) {
           memcpy(mb.mtext, data, sizeof(mb.mtext));
           data += sizeof(mb.mtext);
           if (msgsnd_ex(tp->msg_id, &mb, sizeof(mb.mtext), 0) == -1)
               aborted("Failed to do block msgsnd");
       }
       residue = size % sizeof(mb.mtext);
       if (residue > 0) {
           memcpy(mb.mtext, data, residue);
           if (msgsnd_ex(tp->msg_id, &mb, sizeof(mb.mtext), 0) == -1)
               aborted("Failed to do resid block msgsnd");
       }

       /* Signal */
       p_buf.sem_op = 1;
       if (semop_ex(tp->snd_sem_id, &p_buf, 1) == -1)
           aborted("signal failed");

       shmdt(tp);

       return nulldesc;
   }
end

function{1} ipc_Msg_receive_impl(self)
   body {
       msg_top *tp;
       int size, blocks, residue, i;
       struct sembuf p_buf;
       msghead mh;
       msgblock mb;
       char *data, *p;
       GetSelfId();

       tp = (msg_top*)shmat(self_id, 0, 0);
       if ((void*)tp == (void*)-1)
           aborted("Couldn't attach to shm");

       /* Wait on rcv semaphore */
       p_buf.sem_num = 0;
       p_buf.sem_op = -1;
       p_buf.sem_flg = SEM_UNDO;
       if (semop_ex(tp->rcv_sem_id, &p_buf, 1) == -1)
           aborted("wait failed");

       if (msgrcv_ex(tp->msg_id, &mh, sizeof(mh.u), 0, 0) == -1) {
           aborted("Failed to do header msgrcv");
       }
       size = mh.u.size;
       blocks = size / sizeof(mb.mtext);

       MemProtect(p = data = malloc(size));
   
       for (i = 0; i < blocks; ++i) {
           if (msgrcv_ex(tp->msg_id, &mb, sizeof(mb.mtext), 0, 0) == -1)
               aborted("Failed to do block msgrcv");
           memcpy(data, mb.mtext, sizeof(mb.mtext));
           data += sizeof(mb.mtext);
       }
       residue = size % sizeof(mb.mtext);
       if (residue > 0) {
           if (msgrcv_ex(tp->msg_id, &mb, sizeof(mb.mtext), 0, 0) == -1)
               aborted("Failed to do resid block msgrcv");
           memcpy(data, mb.mtext, residue);
       }

       bytes2string(p, size, &result);
       free(p);

       /* Signal */
       p_buf.sem_op = 1;
       if (semop_ex(tp->rcv_sem_id, &p_buf, 1) == -1)
           aborted("signal failed");
   
       shmdt(tp);

       return result;
   }
end

function{0,1} ipc_Msg_attempt_impl(self)
   body {
       msg_top *tp;
       int size, blocks, residue, i;
       struct sembuf p_buf;
       msghead mh;
       msgblock mb;
       char *data, *p;
       GetSelfId();

       tp = (msg_top*)shmat(self_id, 0, 0);
       if ((void*)tp == (void*)-1)
           aborted("Couldn't attach to shm");

       /* Wait on rcv semaphore */
       p_buf.sem_num = 0;
       p_buf.sem_op = -1;
       p_buf.sem_flg = SEM_UNDO;

       if (semop_ex(tp->rcv_sem_id, &p_buf, 1) == -1)
           aborted("wait failed");
       if (msgrcv_ex(tp->msg_id, &mh, sizeof(mh.u), 0, IPC_NOWAIT) == -1) {
           if (errno == ENOMSG) {
               /* Okay, it's not ready,so fail.  First signal. */
               errno2why();
               p_buf.sem_op = 1;
               if (semop_ex(tp->rcv_sem_id, &p_buf, 1) == -1)
                   aborted("signal failed");
               fail;
           }
           aborted("Failed to do header msgrcv");
       }
       size = mh.u.size;
       blocks = size / sizeof(mb.mtext);

       MemProtect(p = data = malloc(size));
   
       for (i = 0; i < blocks; ++i) {
           if (msgrcv_ex(tp->msg_id, &mb, sizeof(mb.mtext), 0, 0) == -1)
               aborted("Failed to do block msgrcv");
           memcpy(data, mb.mtext, sizeof(mb.mtext));
           data += sizeof(mb.mtext);
       }
       residue = size % sizeof(mb.mtext);
       if (residue > 0) {
           if (msgrcv_ex(tp->msg_id, &mb, sizeof(mb.mtext), 0, 0) == -1)
               aborted("Failed to do resid block msgrcv");
           memcpy(data, mb.mtext, residue);
       }

       bytes2string(p, size, &result);
       free(p);

       /* Signal */
       p_buf.sem_op = 1;
       if (semop_ex(tp->rcv_sem_id, &p_buf, 1) == -1)
           aborted("signal failed");
   
       shmdt(tp);

       return result;
   }
end

/*
 * These wrappers are needed because msgsnd, msgrcv and semop return
 * -1 (errno=EINTR) if a signal is received during execution.  In
 * particular, SIGPROF seems to do this.  Setting SA_RESTART on the
 * handler's flags doesn't seem to work.  Ignoring the signal does
 * work, but that prevents anyone else actually trapping the signal.
 */

static int msgsnd_ex(int msqid, void *msgp, size_t msgsz, int msgflg) {
    int i;

    do {
        i = msgsnd(msqid, msgp, msgsz, msgflg);
    } while (i == -1 && errno == EINTR);

    return i;
}

static ssize_t msgrcv_ex(int msqid, void *msgp, size_t msgsz, long msgtyp, int msgflg) {
    ssize_t i;

    do {
        i = msgrcv(msqid, msgp, msgsz, msgtyp, msgflg);
    } while (i == -1 && errno == EINTR);

    return i;
}

static int semop_ex(int semid, struct sembuf *sops, size_t nsops) {
    int i;

    do {
        i = semop(semid, sops, nsops);
    } while (i == -1 && errno == EINTR);

    return i;
}

static void add_resource(int id, int type) {
    static int inited = 0;
    int i;

    if (!inited) {
        struct sigaction sigact;

        /* Signals to handle */
        sigact.sa_handler = handler;
        sigact.sa_flags = 0;
        sigfillset(&sigact.sa_mask);
        sigaction(SIGINT, &sigact, 0);
        sigaction(SIGTERM, &sigact, 0);
        sigaction(SIGPIPE, &sigact, 0);

        atexit(cleanup);
        inited = 1;
    }

    for (i = 0; i < num_resources; ++i) {
        if (resources[i].pid == -1) {
            resources[i].pid = getpid();
            resources[i].type = type;
            resources[i].id = id;
            return;
        }
    }
    if (num_resources >= MAX_RESOURCES)
        return;
    resources[num_resources].pid = getpid();
    resources[num_resources].type = type;
    resources[num_resources].id = id;
    ++num_resources;
}

static void remove_resource(int id, int type) {
    int i;
    for (i = 0; i < num_resources; ++i) {
        if (resources[i].type == type && resources[i].id == id) {
            resources[i].pid = -1;
            return;
        }
    }
}

static void aborted(char *s) {
    ffatalerr("ipc.r: %s; program will abort\n"
              "errnum=%d (%s)\n", s, errno, strerror(errno));
}

static void cleanup() {
    int pid;
    int i;

    pid = getpid();
    for (i = 0; i < num_resources; ++i) {
        if (resources[i].pid == pid) {
            fprintf(stderr, "ipc: Removing resource type %d id=%d\n", resources[i].type, resources[i].id);
            switch (resources[i].type) {
                case 0: {
                    shm_top *tp = (shm_top*)shmat(resources[i].id, 0, 0);
                    if ((void*)tp == (void*)-1)
                        break;
                    shmctl(tp->data_id, IPC_RMID, 0);
                    semctl(tp->sem_id, -1, IPC_RMID, 0);
                    shmctl(resources[i].id, IPC_RMID, 0);
                    shmdt(tp);
                    break;
                }
                case 1:
                    semctl(resources[i].id, -1, IPC_RMID, 0);
                    break;
                case 2: {
                    msg_top *tp = (msg_top*)shmat(resources[i].id, 0, 0);
                    if ((void*)tp == (void*)-1)
                        break;
                    semctl(tp->rcv_sem_id, -1, IPC_RMID, 0);
                    semctl(tp->snd_sem_id, -1, IPC_RMID, 0);
                    msgctl(tp->msg_id, IPC_RMID, 0);
                    shmctl(resources[i].id, IPC_RMID, 0);
                    shmdt(tp);
                    break;
                }
            }
            resources[i].pid = -1;
        }
    }
   
}

static void handler(int signo) {
    fprintf(stderr, "ipc: Caught signal %d; program will cleanup and exit\n", signo);
    cleanup();
    exit(1);
}
